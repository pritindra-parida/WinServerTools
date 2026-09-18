#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
    Unit tests for PS-MultiServerFileCopy helper functions.

    Tests run without real server access using temp files and placeholder names.

    To run:
        Invoke-Pester -Path .\tests\PS-MultiServerFileCopy.Tests.ps1 -Output Detailed

    Requires Pester v5.0+:
        Install-Module -Name Pester -MinimumVersion 5.0 -Force -Scope CurrentUser
#>

BeforeAll {
    # Redefine the two pure helper functions from src\PS-MultiServerFileCopy.ps1 here
    # so they can be tested without executing the full script (which has Mandatory params).

    function Get-UncPath {
        param ([string]$Server, [string]$LocalPath)
        if ($LocalPath -match '^([A-Za-z]):\\?(.*)$') {
            $drive = $Matches[1].ToUpper()
            $tail  = $Matches[2].TrimStart('\')
            if ($tail) { return "\\$Server\${drive}`$\$tail" }
            return "\\$Server\${drive}`$"
        }
        return "\\$Server\$LocalPath"
    }

    function Read-ServerFile {
        param ([string]$FilePath)
        if (-not (Test-Path -LiteralPath $FilePath)) { return @() }
        return @(
            Get-Content -LiteralPath $FilePath |
            Where-Object { $_.Trim() -ne '' -and $_ -notmatch '^\s*#' } |
            ForEach-Object { $_.Trim() }
        )
    }
}

# --------------------------------------------------------------------------
# Get-UncPath
# --------------------------------------------------------------------------

Describe 'Get-UncPath' {

    It 'Converts a drive and subfolder path' {
        Get-UncPath -Server 'SERVER01' -LocalPath 'C:\Updates\App' |
            Should -Be '\\SERVER01\C$\Updates\App'
    }

    It 'Converts a drive root with trailing backslash' {
        Get-UncPath -Server 'SERVER01' -LocalPath 'C:\' |
            Should -Be '\\SERVER01\C$'
    }

    It 'Converts a drive root without trailing backslash' {
        Get-UncPath -Server 'SERVER01' -LocalPath 'C:' |
            Should -Be '\\SERVER01\C$'
    }

    It 'Uppercases the drive letter' {
        Get-UncPath -Server 'SERVER01' -LocalPath 'd:\Logs' |
            Should -Be '\\SERVER01\D$\Logs'
    }

    It 'Handles paths with spaces' {
        Get-UncPath -Server 'SERVER01' -LocalPath 'C:\Program Files\App' |
            Should -Be '\\SERVER01\C$\Program Files\App'
    }

    It 'Passes an unrecognised format through with server prefix' {
        Get-UncPath -Server 'SERVER01' -LocalPath 'SomeShare\Path' |
            Should -Be '\\SERVER01\SomeShare\Path'
    }

    It 'Includes the provided server name in the result' {
        Get-UncPath -Server 'MYSERVER' -LocalPath 'D:\Data' |
            Should -Match '^\\\\MYSERVER\\'
    }
}

# --------------------------------------------------------------------------
# Source validation (direct Test-Path checks)
# --------------------------------------------------------------------------

Describe 'Source validation' {

    Context 'Given a path that does not exist' {
        It 'Test-Path returns false' {
            Test-Path -LiteralPath 'X:\DoesNotExist\Fake' | Should -Be $false
        }
    }

    Context 'Given a file that exists' {
        BeforeAll { $script:f = [System.IO.Path]::GetTempFileName() }
        AfterAll  { Remove-Item -LiteralPath $script:f -Force -ErrorAction SilentlyContinue }

        It 'Test-Path returns true' {
            Test-Path -LiteralPath $script:f | Should -Be $true
        }
    }

    Context 'Given a directory that exists' {
        BeforeAll {
            $script:d = Join-Path $env:TEMP "MsfcTest_$(Get-Random)"
            New-Item -ItemType Directory -Path $script:d -Force | Out-Null
        }
        AfterAll { Remove-Item -LiteralPath $script:d -Recurse -Force -ErrorAction SilentlyContinue }

        It 'Test-Path returns true' {
            Test-Path -LiteralPath $script:d | Should -Be $true
        }
    }
}

# --------------------------------------------------------------------------
# Server file parsing
# --------------------------------------------------------------------------

Describe 'Server file parsing' {

    BeforeAll {
        $script:file = Join-Path $env:TEMP "servers_$(Get-Random).txt"
        Set-Content -LiteralPath $script:file -Encoding UTF8 -Value @'
# Comment line
SERVER01
SERVER02

# Another comment
SERVER03
'@
    }

    AfterAll { Remove-Item -LiteralPath $script:file -Force -ErrorAction SilentlyContinue }

    It 'Returns the correct server count' {
        (Read-ServerFile -FilePath $script:file).Count | Should -Be 3
    }

    It 'Excludes comment lines' {
        Read-ServerFile -FilePath $script:file | Should -Not -Contain '# Comment line'
    }

    It 'Excludes blank lines' {
        Read-ServerFile -FilePath $script:file | Should -Not -Contain ''
    }

    It 'Contains each expected server name' {
        $result = Read-ServerFile -FilePath $script:file
        $result | Should -Contain 'SERVER01'
        $result | Should -Contain 'SERVER02'
        $result | Should -Contain 'SERVER03'
    }

    It 'Returns empty array for a missing file' {
        (Read-ServerFile -FilePath 'X:\does\not\exist.txt').Count | Should -Be 0
    }
}

# --------------------------------------------------------------------------
# Exit code validation (calls the script as a subprocess)
# --------------------------------------------------------------------------

Describe 'Script exit codes' {

    BeforeAll {
        $script:ps = "$PSScriptRoot\..\src\PS-MultiServerFileCopy.ps1"
    }

    It 'Exits with code 3 when source does not exist' {
        & powershell.exe -NonInteractive -File $script:ps `
            -Source 'X:\NoSuchPath' -Servers 'SERVER01' -DestinationPath 'C:\Test' 2>$null
        $LASTEXITCODE | Should -Be 3
    }

    It 'Exits with code 3 when no servers are specified' {
        # Passing an empty string list forces the count to 0 after filtering
        & powershell.exe -NonInteractive -File $script:ps `
            -Source $env:TEMP -Servers '' -DestinationPath 'C:\Test' 2>$null
        $LASTEXITCODE | Should -Be 3
    }

    It 'Exits with code 3 when a server name contains invalid characters' {
        & powershell.exe -NonInteractive -File $script:ps `
            -Source $env:TEMP -Servers 'INVALID!' -DestinationPath 'C:\Test' 2>$null
        $LASTEXITCODE | Should -Be 3
    }
}
