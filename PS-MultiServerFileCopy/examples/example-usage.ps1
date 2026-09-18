#Requires -Version 5.1

<#
    Example usage for PS-MultiServerFileCopy.ps1
    ------------------------------------------
    Replace SERVER01, SERVER02, etc. with actual server names in your environment.
    Replace paths with paths that exist and are accessible to the running user.
#>

$script = "$PSScriptRoot\..\src\PS-MultiServerFileCopy.ps1"

# Basic: copy a file to two servers
& $script `
    -Source          "C:\Example\update.zip" `
    -Servers         SERVER01, SERVER02 `
    -DestinationPath "C:\Updates"


# Copy a folder to servers listed in a file
& $script `
    -Source          "C:\Example\AppPackage" `
    -ServersFile     "$PSScriptRoot\servers-example.txt" `
    -DestinationPath "D:\Deployments"


# Custom retry settings
& $script `
    -Source           "C:\Example\patch.msi" `
    -Servers          SERVER01, SERVER02, SERVER03 `
    -DestinationPath  "C:\Patches" `
    -MaxRetries       5 `
    -RetryWaitSeconds 30


# No retries (fail immediately on error)
& $script `
    -Source          "C:\Example\config.xml" `
    -Servers         SERVER01 `
    -DestinationPath "C:\AppConfig" `
    -MaxRetries      0


# Custom log file location
& $script `
    -Source          "C:\Example\data.csv" `
    -Servers         SERVER01 `
    -DestinationPath "C:\Data" `
    -LogPath         "C:\Logs\deploy_$(Get-Date -Format 'yyyyMMdd').log"


# Combine inline servers and a servers file
& $script `
    -Source          "C:\Example\update.zip" `
    -Servers         SERVER01 `
    -ServersFile     "$PSScriptRoot\servers-example.txt" `
    -DestinationPath "C:\Updates"
