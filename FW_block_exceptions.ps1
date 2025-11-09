# Define the allowed IP addresses
$AllowedIPs = "192.168.1.10", "10.0.0.5" # Replace with your actual IP addresses

# Define the backup file path
$BackupPath = "$env:TEMP\FirewallSettingsBackup.wfw"

# Define the duration for the block (in seconds, 1 hour = 3600 seconds)
$DurationSeconds = 3600

Write-Host "Starting temporary firewall block procedure..."

# 1. Backup current firewall settings
Write-Host "Backing up current firewall settings to $BackupPath..."
netsh advfirewall export "$BackupPath"

# 2. Modify firewall settings: Set default action to Block for all profiles (Domain, Private, Public)
Write-Host "Setting default inbound and outbound actions to Block..."
Set-NetFirewallProfile -Profile Domain, Private, Public -DefaultInboundAction Block -DefaultOutboundAction Block

# 3. Add rules to allow the specific IP addresses (inbound and outbound)
Write-Host "Adding rules to allow specific IP addresses: $AllowedIPs..."
foreach ($ip in $AllowedIPs) {
    # Allow Inbound traffic from specific IP
    New-NetFirewallRule -DisplayName "Temp Allow Inbound $ip" -Direction Inbound -Action Allow -RemoteAddress $ip -Protocol Any -EdgeTraversalPolicy Block
    
    # Allow Outbound traffic to specific IP
    New-NetFirewallRule -DisplayName "Temp Allow Outbound $ip" -Direction Outbound -Action Allow -RemoteAddress $ip -Protocol Any -EdgeTraversalPolicy Block
}

Write-Host "Firewall rules updated. Waiting for 1 hour ($DurationSeconds seconds)..."

# 4. Wait for the specified duration
Start-Sleep -Seconds $DurationSeconds

# 5. Restore original firewall settings
Write-Host "Time elapsed. Restoring original firewall settings from $BackupPath..."

# Disable the temporary rules first to ensure no conflicts during import
Get-NetFirewallRule -DisplayName "Temp Allow Inbound*" | Disable-NetFirewallRule
Get-NetFirewallRule -DisplayName "Temp Allow Outbound*" | Disable-NetFirewallRule
Get-NetFirewallRule -DisplayName "Temp Allow Inbound*" | Remove-NetFirewallRule
Get-NetFirewallRule -DisplayName "Temp Allow Outbound*" | Remove-NetFirewallRule

# The 'netsh import' command overwrites current settings with the backup file's content
netsh advfirewall import "$BackupPath"

# Clean up the backup file
if (Test-Path $BackupPath) {
    Remove-Item $BackupPath
    Write-Host "Backup file deleted."
}

Write-Host "Firewall settings restored successfully. Script finished."
