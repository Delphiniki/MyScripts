$topic = "topic_name" # Use a secure, unguessable topic name
$username = "username"
$password = "password"
$messageBody = "Hello friend, this is just a test."
$messageTitle = "Security Alert"
$ntfyServer = "https://ntfy.sh"

# This is a secure way to handle credentials in PowerShell
$credential = New-Object System.Management.Automation.PSCredential($username, (ConvertTo-SecureString $password -AsPlainText -Force))

# Encode credentials for Basic Authentication
$authHeader = "Basic " + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($username + ":" + $password))

# Define the request parameters
$requestParams = @{
    Method  = "POST"
    URI     = "$($ntfyServer)/$($topic)"
    Body    = $messageBody
    Headers = @{
        "Title"      = $messageTitle
        "Authorization" = $authHeader
    }
}

# Send the notification
try {
    Invoke-RestMethod @requestParams
    Write-Host "Ntfy message sent successfully to topic '$topic'."
}
catch {
    Write-Host "An error occurred: $($_.Exception.Message)"
}
