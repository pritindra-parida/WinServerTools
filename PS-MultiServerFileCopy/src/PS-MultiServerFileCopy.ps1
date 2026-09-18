#Requires -Version 5.1

<#
.SYNOPSIS
    Copies a file or folder to multiple Windows servers.

.DESCRIPTION
    Uses the current Windows user's security context for all network access.
    No credentials are stored, prompted for, or managed by this script.
    The executing user must already have the required permissions on every
    destination server involved in the operation.

    Destination paths are expressed as local Windows paths (e.g. C:\Updates)
    and are automatically converted to UNC admin share paths (\\SERVER\C$\Updates).

.PARAMETER Source
    Path to the source file or folder (local or UNC).

.PARAMETER Servers
    One or more server names. Can be combined with -ServersFile.

.PARAMETER ServersFile
    Path to a text file containing one server name per line.
    Lines beginning with '#' and blank lines are ignored.

.PARAMETER DestinationPath
    Destination path on each server expressed as a local Windows path,
    e.g. C:\Updates or D:\Deployments.
    The script converts this to a UNC admin share path automatically.

.PARAMETER MaxRetries
    Additional attempts per server after an initial failure (0-10). Default: 3.

.PARAMETER RetryWaitSeconds
    Seconds to wait between retries (1-300). Default: 10.

.PARAMETER LogPath
    Path to the log file. Defaults to a timestamped file in the logs folder.

.EXAMPLE
    .\PS-MultiServerFileCopy.ps1 -Source "C:\Files\update.zip" `
        -Servers SERVER01, SERVER02, SERVER03 `
        -DestinationPath "C:\Updates"

.EXAMPLE
    .\PS-MultiServerFileCopy.ps1 -Source "C:\Packages\App" `
        -ServersFile ".\servers.txt" `
        -DestinationPath "D:\Deployments" `
        -MaxRetries 5 -RetryWaitSeconds 20

.NOTES
    Exit codes:
        0  All copies succeeded.
        1  Partial success (at least one server succeeded, at least one failed).
        2  All copies failed.
        3  Input validation error - no copies were attempted.

    Requires network access and appropriate Windows permissions on each target
    server (typically local Administrator to access admin shares C$, D$, etc.).
#>

Set-StrictMode -Version Latest

[CmdletBinding()]
param (
    [Parameter(Mandatory)] [string]   $Source,
    [Parameter()]          [string[]] $Servers         = @(),
    [Parameter()]          [string]   $ServersFile     = '',
    [Parameter(Mandatory)] [string]   $DestinationPath,
    [Parameter()] [ValidateRange(0, 10)]  [int] $MaxRetries       = 3,
    [Parameter()] [ValidateRange(1, 300)] [int] $RetryWaitSeconds = 10,
    [Parameter()]          [string]   $LogPath         = ''
)

# --------------------------------------------------------------------------
# Helper functions
# --------------------------------------------------------------------------

function Write-Log {
    param ([string]$Server = '-', [string]$Status, [string]$Message)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`t$Server`t$Status`t$Message"
    try {
        Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-Warning "Logging failed: $_"
    }
}

function Get-UncPath {
    param ([string]$Server, [string]$LocalPath)
    # Convert C:\path to \\SERVER\C$\path  or  C:\ to \\SERVER\C$
    if ($LocalPath -match '^([A-Za-z]):\\?(.*)$') {
        $drive = $Matches[1].ToUpper()
        $tail  = $Matches[2].TrimStart('\')
        if ($tail) { return "\\$Server\${drive}`$\$tail" }
        return "\\$Server\${drive}`$"
    }
    return "\\$Server\$LocalPath"
}

# --------------------------------------------------------------------------
# Resolve log path
# --------------------------------------------------------------------------

if (-not $LogPath) {
    $logsDir = Join-Path $PSScriptRoot 'logs'
    $LogPath = Join-Path $logsDir "PS-MultiServerFileCopy_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
}

$logDir = Split-Path $LogPath -Parent
if ($logDir -and -not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -LiteralPath $logDir -Force | Out-Null
}

# --------------------------------------------------------------------------
# Resolve server list
# --------------------------------------------------------------------------

$allServers = @($Servers | Where-Object { $_.Trim() -ne '' })

if ($ServersFile) {
    if (-not (Test-Path -LiteralPath $ServersFile)) {
        Write-Host "[ERROR] Servers file not found: $ServersFile" -ForegroundColor Red
        exit 3
    }
    $fileServers = Get-Content -LiteralPath $ServersFile |
        Where-Object { $_.Trim() -ne '' -and $_ -notmatch '^\s*#' } |
        ForEach-Object { $_.Trim() }
    $allServers += $fileServers
}

if ($allServers.Count -eq 0) {
    Write-Host "[ERROR] No servers specified. Use -Servers or -ServersFile." -ForegroundColor Red
    exit 3
}

$validNamePattern = '^[A-Za-z0-9]([A-Za-z0-9\-\.]{0,61}[A-Za-z0-9])?$'
$invalidNames = @($allServers | Where-Object { $_ -notmatch $validNamePattern })
if ($invalidNames.Count -gt 0) {
    Write-Host "[ERROR] Invalid server name(s): $($invalidNames -join ', ')" -ForegroundColor Red
    exit 3
}

# --------------------------------------------------------------------------
# Validate source
# --------------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $Source)) {
    Write-Host "[ERROR] Source not found: $Source" -ForegroundColor Red
    exit 3
}

Write-Log -Status 'INFO' -Message "Session started. Source=$Source Dest=$DestinationPath Servers=$($allServers -join ',')"
Write-Host "[INFO] Source         : $Source"
Write-Host "[INFO] Destination    : $DestinationPath"
Write-Host "[INFO] Server count   : $($allServers.Count)"

# --------------------------------------------------------------------------
# Copy to each server
# --------------------------------------------------------------------------

$successCount = 0
$failedCount  = 0
$totalRetries = 0
$failedList   = @()

foreach ($server in $allServers) {
    $dest = Get-UncPath -Server $server -LocalPath $DestinationPath

    Write-Host ''
    Write-Host "Copying to $server..."
    Write-Log -Server $server -Status 'INFO' -Message "Starting. Dest: $dest"

    if (-not (Test-Connection -ComputerName $server -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
        Write-Host "[ERROR] $server - Server unreachable." -ForegroundColor Red
        Write-Log -Server $server -Status 'ERROR' -Message 'Server unreachable'
        $failedCount++
        $failedList += "$server (unreachable)"
        continue
    }

    $attempt   = 0
    $succeeded = $false
    $lastError = ''

    while ($attempt -le $MaxRetries -and -not $succeeded) {
        $attempt++
        try {
            if (-not (Test-Path -LiteralPath $dest)) {
                New-Item -ItemType Directory -LiteralPath $dest -Force -ErrorAction Stop | Out-Null
            }
            Copy-Item -LiteralPath $Source -Destination $dest -Recurse -Force -ErrorAction Stop
            $succeeded = $true
        }
        catch {
            $lastError = $_.Exception.Message
            if ($attempt -le $MaxRetries) {
                Write-Host "[RETRY] $server - Attempt $attempt failed. Retrying in ${RetryWaitSeconds}s..." -ForegroundColor Yellow
                Write-Log -Server $server -Status 'RETRY' -Message "Attempt $attempt failed: $lastError"
                $totalRetries++
                Start-Sleep -Seconds $RetryWaitSeconds
            }
        }
    }

    if ($succeeded) {
        Write-Host "[SUCCESS] $server" -ForegroundColor Green
        Write-Log -Server $server -Status 'SUCCESS' -Message "Copied successfully on attempt $attempt"
        $successCount++
    }
    else {
        Write-Host "[ERROR] $server - $lastError" -ForegroundColor Red
        Write-Log -Server $server -Status 'ERROR' -Message "Failed after $attempt attempt(s): $lastError"
        $failedCount++
        $failedList += $server
    }
}

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------

Write-Host ''
Write-Host 'Execution Summary'
Write-Host ('-' * 40)
Write-Host "Total   : $($allServers.Count)"
Write-Host "Success : $successCount"
Write-Host "Failed  : $failedCount"
Write-Host "Retries : $totalRetries"

if ($failedList.Count -gt 0) {
    Write-Host ''
    Write-Host 'Failed servers:'
    $failedList | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
}

Write-Host ''
Write-Host "Log: $LogPath"

Write-Log -Status 'INFO' -Message "Session complete. Total=$($allServers.Count) Success=$successCount Failed=$failedCount Retries=$totalRetries"

if ($failedCount -eq 0)      { exit 0 }
elseif ($successCount -gt 0) { exit 1 }
else                         { exit 2 }
