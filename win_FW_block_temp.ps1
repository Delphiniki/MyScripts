# Requires admin privileges to run

$tempPath = "C:\Temp"
$backupPath = "$tempPath\Firewall_Backup.wfw"
$restoreScriptPath = "C:\Temp\Restore-Firewall.ps1"
$allowedIp = "10.1.1.2"
$taskName = "RestoreFirewallSettingsTask"

# Check if the directory does not exist
if (-not (Test-Path -Path $tempPath -PathType Container)) {
    # If it doesn't exist, create it
    New-Item -Path $tempPath -ItemType Directory | Out-Null}

# 1. Copy all firewall profile settings to a file
Write-Host "Backing up current firewall settings to $backupPath..."
# Use netsh to export all firewall rules and policies
netsh advfirewall export $backupPath
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to export firewall settings. Exiting."
    exit 1
}
Write-Host "Backup successful."

# 2. Block the firewall except IP address 10.1.1.2

# Set default inbound and outbound action to Block for all profiles (Domain, Private, Public)
# Note: This blocks all connections *except* those explicitly allowed by existing rules
Write-Host "Setting default inbound and outbound action to Block for all profiles..."
Set-NetFirewallProfile -Profile Domain, Private, Public -DefaultInboundAction Block -DefaultOutboundAction Block

# Create an "Allow" rule for the specific IP address (10.1.1.2)
Write-Host "Creating 'Allow' rule for IP $allowedIp..."
New-NetFirewallRule -DisplayName "Allow Specific IP Temp" -Direction Inbound -Protocol Any -Action Allow -RemoteAddress $allowedIp -Enabled True -Profile Any

# 3. Create a scheduled task which will restore all firewall settings after 2 hours.

# First, create the restore script that the scheduled task will run
Write-Host "Creating restore script: $restoreScriptPath..."
$restoreScriptContent = @"
# Restore script created by Manage-Firewall.ps1
# Runs with highest privileges
`$zbackupPath` = "$backupPath"
`$ztaskName` = "$taskName"

Write-Host "Importing firewall settings from `$zbackupPath`..."
netsh advfirewall import `$zbackupPath`

# Start-Sleep 5

Write-Host "Removing the scheduled task..."
Unregister-ScheduledTask -TaskName `"$ztaskName"` -Confirm:`$false`

Write-Host "Deleting backup file: `$zbackupPath` "
Remove-Item -Path `$zbackupPath` -Force

Write-Host "Firewall settings restored and task/backup deleted."

# Command to delete the script file itself
Remove-Item -LiteralPath `$PSCommandPath` -Force

# Exit the restore script
Exit
"@
$restoreScriptContent | Out-File -FilePath $restoreScriptPath -Encoding Default


# 5. Create a scheduled task to run the restore script after 2 hours
Write-Host "Creating scheduled task '$taskName' to run in 2 hours..."

$taskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File $restoreScriptPath"
# Trigger to run once, 2 hours from now
$startTime = (Get-Date).AddHours(2)
$taskTrigger = New-ScheduledTaskTrigger -Once -At $startTime
$taskPrincipal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$taskSettings = New-ScheduledTaskSettingsSet

Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal -Settings $taskSettings -Force | Out-Null

Write-Host "Script execution complete. Firewall is now restricted. Restore task scheduled for 2 hours later."
# Exit the main script
Exit
