# Changelog

## [Unreleased] - Planned for Version 2

- Parallel execution across servers (runspaces or PowerShell jobs)
- `-SkipConnectivityCheck` flag for firewalled environments
- `-WhatIf` dry-run mode
- Optional CSV/HTML summary report

---

## [1.0.0] - Initial Release

### Added

- `src\PS-MultiServerFileCopy.ps1` — single script that copies a file or folder to multiple servers.
- Source path validation before any copy is attempted.
- Server name validation against a standard hostname character pattern; invalid names cause an immediate exit with code 3 before any copies are attempted.
- Server reachability check (ICMP ping) before each copy.
- Automatic conversion of local Windows paths to UNC admin share paths (`C:\Updates` → `\\SERVER\C$\Updates`).
- Destination directory creation on each server when the path does not exist.
- Sequential copy to each server using the current Windows user's security context.
- Configurable retry mechanism (`-MaxRetries`, `-RetryWaitSeconds`).
- Tab-separated log file written to `src\logs\` by default (alongside the script), overridable with `-LogPath`.
- Log write failures surfaced as console warnings; copy operations continue regardless.
- `Set-StrictMode -Version Latest` enforced to catch undefined variable references.
- Wildcard-safe path handling via `-LiteralPath` for all file system operations.
- Console output with `[INFO]`, `[SUCCESS]`, `[ERROR]`, and `[RETRY]` prefixes.
- Execution summary showing total, successful, and failed servers, with a failed server list.
- Exit codes: `0` (all success), `1` (partial), `2` (all failed), `3` (input validation error).
- `-Servers` and `-ServersFile` parameters for specifying targets (combinable).
- `examples\example-usage.ps1` with common usage patterns.
- `examples\servers-example.txt` sample servers file.
- `tests\PS-MultiServerFileCopy.Tests.ps1` — Pester v5 tests covering UNC path conversion, source validation, server file parsing, server name validation, and script exit codes.
