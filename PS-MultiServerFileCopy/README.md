# PS-MultiServerFileCopy

A small PowerShell utility that copies a file or folder to multiple Windows servers in one run.

---

## What It Does

1. Accepts a source file or folder and a list of destination servers.
2. Checks each server is reachable before attempting a copy.
3. Copies the source to the destination path on each server using Windows file sharing.
4. Retries failed copies a configurable number of times.
5. Logs every operation to a text file and prints a summary at the end.

---

## Authentication

**The script uses the Windows security context of the user running it.**

No credentials are stored, prompted for, or managed by this script. The executing user must already have the required permissions on every destination server — typically local Administrator access to use admin shares (`C$`, `D$`, etc.).

```
Execution machine
     |
     | (current Windows user identity)
     |
     +---> SERVER01
     +---> SERVER02
     +---> SERVER03
     +---> ...
```

If the user does not have the required access, the copy will fail with an access denied error. Authentication is an infrastructure concern, not a script concern.

---

## Requirements

- **PowerShell 5.1** or later (Windows PowerShell, included with Windows)
- Network access (SMB, TCP 445) to each destination server
- Appropriate Windows permissions on each target server

For running tests only: **Pester 5.0+**

---

## Usage

```powershell
.\src\PS-MultiServerFileCopy.ps1 -Source <path> -Servers <name[,name...]> -DestinationPath <path> [options]
```

```powershell
.\src\PS-MultiServerFileCopy.ps1 -Source <path> -ServersFile <file> -DestinationPath <path> [options]
```

### Parameters

| Parameter | Required | Default | Description |
|---|---|---|---|
| `-Source` | Yes | | Path to the source file or folder. |
| `-Servers` | See note | | One or more server names, comma-separated. |
| `-ServersFile` | See note | | Text file with one server name per line. |
| `-DestinationPath` | Yes | | Local path on each server, e.g. `C:\Updates`. |
| `-MaxRetries` | No | `3` | Additional attempts per server after a failure (0-10). |
| `-RetryWaitSeconds` | No | `10` | Seconds between retries (1-300). |
| `-LogPath` | No | auto | Full path to the log file. |

**Note:** At least one of `-Servers` or `-ServersFile` is required. Both can be used together — their lists are combined.

---

## Examples

**Copy a file to three servers:**

```powershell
.\src\PS-MultiServerFileCopy.ps1 `
    -Source "C:\Releases\update.zip" `
    -Servers SERVER01, SERVER02, SERVER03 `
    -DestinationPath "C:\Updates"
```

**Copy a folder using a servers file:**

```powershell
.\src\PS-MultiServerFileCopy.ps1 `
    -Source "C:\Packages\MyApp" `
    -ServersFile ".\examples\servers-example.txt" `
    -DestinationPath "D:\Deployments"
```

**Custom retry settings:**

```powershell
.\src\PS-MultiServerFileCopy.ps1 `
    -Source "C:\Patches\hotfix.msi" `
    -Servers SERVER01, SERVER02 `
    -DestinationPath "C:\Patches" `
    -MaxRetries 5 -RetryWaitSeconds 30
```

**No retries (fail immediately):**

```powershell
.\src\PS-MultiServerFileCopy.ps1 `
    -Source "C:\Config\app.config" `
    -Servers SERVER01 `
    -DestinationPath "C:\AppConfig" `
    -MaxRetries 0
```

---

## Destination Path

The `-DestinationPath` value is a local Windows path on each target server. It is converted automatically to a UNC admin share path.

| Input | UNC path used |
|---|---|
| `C:\Updates` | `\\SERVER\C$\Updates` |
| `D:\Deployments\App` | `\\SERVER\D$\Deployments\App` |
| `C:\` | `\\SERVER\C$` |

The destination directory is created on the target server if it does not already exist.

The source file or folder is placed **inside** the destination directory. For example, copying `C:\Files\update.zip` with `-DestinationPath "C:\Updates"` produces `C:\Updates\update.zip` on the server.

---

## Servers File Format

```
# Lines beginning with # are comments
SERVER01
SERVER02

# Staging
SERVER03
```

- One server name or hostname per line.
- Blank lines and comment lines (starting with `#`) are ignored.
- Server names must contain only letters, digits, hyphens, and dots. Names that do not match this pattern cause the script to exit with code 3 before any copies are attempted.

---

## Console Output

```
[INFO] Source         : C:\Releases\update.zip
[INFO] Destination    : C:\Updates
[INFO] Server count   : 3

Copying to SERVER01...
[SUCCESS] SERVER01

Copying to SERVER02...
[RETRY] SERVER02 - Attempt 1 failed. Retrying in 10s...
[SUCCESS] SERVER02

Copying to SERVER03...
[ERROR] SERVER03 - Server unreachable.

Execution Summary
----------------------------------------
Total   : 3
Success : 2
Failed  : 1
Retries : 1

Failed servers:
  - SERVER03 (unreachable)

Log: C:\...\logs\PS-MultiServerFileCopy_20260826_120000.log
```

---

## Logging

- Default log location: `logs\PS-MultiServerFileCopy_yyyyMMdd_HHmmss.log` (relative to the script location).
- Override with `-LogPath "C:\MyLogs\run.log"`.
- Tab-separated format: `timestamp | server | status | message`
- Log files are excluded from version control by `.gitignore`.
- If the log file cannot be written (e.g. insufficient permissions or full disk), a warning is printed to the console and the copy operation continues.

---

## Retry Behaviour

- `-MaxRetries 3` (default) means one initial attempt plus up to 3 retries — 4 total attempts per server.
- `-MaxRetries 0` means one attempt, no retries.
- Retries do not apply to servers that fail the connectivity check.
- Each retry is logged separately.

---

## Exit Codes

| Code | Meaning |
|---|---|
| `0` | All copies succeeded. |
| `1` | Partial success. |
| `2` | All copies failed. |
| `3` | Input validation error — no copies were attempted. |

---

## Running Tests

```powershell
Install-Module -Name Pester -MinimumVersion 5.0 -Force -Scope CurrentUser

Invoke-Pester -Path .\tests\PS-MultiServerFileCopy.Tests.ps1 -Output Detailed
```

Tests cover UNC path conversion, source validation, server file parsing, and script exit codes. No real servers are required.

---

## Version 1 Limitations

- Servers are processed **sequentially**. Parallel execution is planned for Version 2.
- The connectivity check uses ICMP ping. If ping is blocked by a firewall but SMB is open, the copy will be skipped. Work around this by removing or checking connectivity separately before running the script.
- Destination path conversion assumes admin shares (`C$`, `D$`). If the target server uses custom share names, specify the full UNC path in a wrapper script.
- Windows only. No cross-platform support.

---

## Planned Version 2

- Parallel execution across servers
- Optional `-SkipConnectivityCheck` flag for firewalled environments
- `-WhatIf` dry-run mode
- CSV/HTML summary report

---

## License

MIT. See [LICENSE](LICENSE).

---

## Contributing

1. Fork the repository.
2. Create a branch: `git checkout -b feature/your-change`
3. Make changes and update or add tests where relevant.
4. Run `Invoke-Pester` and confirm all tests pass.
5. Open a pull request with a clear description.
