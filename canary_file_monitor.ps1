# Monitor-FileChanges.ps1
# Parameters
$FolderPath = "C:\Canary_Folder"
$SnapshotPath = "C:\Snapshot.csv" # **Update this path**
$ActionScriptPath = "C:\Users\peter\Desktop\alert-script.ps1"

$TimeThresholdMinutes = 5


function Create-CanaryFiles {
    if (-not (Test-Path $CanaryFolderPath)) {
        New-Item -Path $CanaryFolderPath -ItemType Directory | Out-Null
    }

    $filesToCreate = @(
        "Executive_Salaries.pdf",
        "Network_Diagram.pdf",
        "Password_List.pdf"
    )

    foreach ($file in $filesToCreate) {
        $filePath = Join-Path -Path $CanaryFolderPath -ChildPath $file
        if (-not (Test-Path $filePath)) {
            # Create a dummy PDF file (sparse file)
            $f = New-Object System.IO.FileStream $filePath, Create, ReadWrite
            $f.SetLength(5MB) # Set dummy size
            $f.Close()
            Add-Content -Path $filePath -Value "This is a fake document used for security monitoring. Any access will trigger an alert."
            Write-Output "Created canary file: $filePath"
        }
    }
}

# --- Creating Canary files function execution ---
Create-CanaryFiles

function Save-FileSnapshot ($Path, $SnapshotFile) {
    # Get all files and folders, select relevant properties and export to XML
    Get-ChildItem -Path $Path -Recurse | Select-Object FullName, LastWriteTime, CreationTime, Length | Export-Clixml -Path $SnapshotFile -Force
}

function Check-FileChanges ($Path, $SnapshotFile, $ActionScriptPath, $ThresholdMinutes) {
    # Check if a snapshot exists
    if (-not (Test-Path $SnapshotFile)) {
        Write-Host "Snapshot file not found. Creating initial snapshot."
        Save-FileSnapshot -Path $Path -SnapshotFile $SnapshotFile
        return
    }

    # Import the previous snapshot
    $PreviousSnapshot = Import-Clixml -Path $SnapshotFile

    # Get the current file system state
    $CurrentSnapshot = Get-ChildItem -Path $Path -Recurse | Select-Object FullName, LastWriteTime, CreationTime, Length, LastAccessTime

    # Get the current time minus the threshold
    $TimeThreshold = (Get-Date).AddMinutes(-$ThresholdMinutes)

    # Compare current and previous snapshots to find changes
    $Changes = Compare-Object -ReferenceObject $PreviousSnapshot -DifferenceObject $CurrentSnapshot -Property FullName, LastWriteTime, CreationTime, Length, LastAccessTime -PassThru

    if ($Changes) {
        Write-Host "Changes detected in the last $ThresholdMinutes minutes!" -ForegroundColor Red
        
        # Filter for changes within the last 10 minutes based on LastWriteTime or CreationTime
        $RecentChanges = $Changes | Where-Object { 
            $_.LastWriteTime -gt $TimeThreshold -or $_.CreationTime -gt $TimeThreshold
        }

        if ($RecentChanges) {
            Write-Host "Recent changes found (last $ThresholdMinutes minutes):" -ForegroundColor Red
            $RecentChanges | Format-List
            
            # Execute the action script
            if (Test-Path $ActionScriptPath) {
                Write-Host "Executing action script: $ActionScriptPath"
                & $ActionScriptPath # Execute the script
            } else {
                Write-Host "Action script not found at $ActionScriptPath" -ForegroundColor Yellow
            }
        } else {
            Write-Host "Changes detected, but none within the last $ThresholdMinutes minutes." -ForegroundColor Green
        }

        # Save a new snapshot for the next comparison
        Save-FileSnapshot -Path $Path -SnapshotFile $SnapshotFile
    } else {
        Write-Host "No changes detected in the folder." -ForegroundColor Green
    }
}

# --- Main execution ---
# Call the function to check for changes and act accordingly
Check-FileChanges -Path $FolderPath -SnapshotFile $SnapshotPath -ActionScript $ActionScriptPath -ThresholdMinutes $TimeThresholdMinutes
