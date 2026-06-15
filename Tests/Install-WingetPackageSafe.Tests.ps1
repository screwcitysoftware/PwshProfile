#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Mocks Install-WinGetPackage, which must exist in the session to be mockable.
BeforeDiscovery {
    $script:HasWinGetClient = [bool](Get-Module -ListAvailable -Name Microsoft.WinGet.Client)
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    Import-Module Microsoft.WinGet.Client -ErrorAction SilentlyContinue
    $script:Module = 'ScrewCitySoftware.PwshProfile'
}

Describe 'Install-WingetPackageSafe' -Skip:(-not $HasWinGetClient) {

    It 'short-circuits without loading the module when the exe already resolves' {
        InModuleScope ScrewCitySoftware.PwshProfile {
            Mock Import-ModuleSafe { }
            Mock Install-WinGetPackage { }
            # pwsh.exe is guaranteed present in a PowerShell 7 test run.
            Install-WingetPackageSafe -Id 'x.y' -Exe 'pwsh.exe' -PathDir 'C:\nope' -CallerName 'Test'
            Should -Invoke Import-ModuleSafe -Times 0 -Exactly
            Should -Invoke Install-WinGetPackage -Times 0 -Exactly
        }
    }

    It 'defaults -PathDir to the WinGet Links directory when omitted' {
        InModuleScope ScrewCitySoftware.PwshProfile {
            Mock Import-ModuleSafe { }
            Mock Install-WinGetPackage { [pscustomobject]@{ Status = 'Ok'; InstallerErrorCode = 0 } }

            $fakeExe = 'sc-not-a-real-exe-' + [guid]::NewGuid() + '.exe'
            $links = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'
            $savedPath = $env:Path
            try {
                # -PathDir omitted: it should resolve to the shared portable Links dir.
                Install-WingetPackageSafe -Id 'Some.Package' -Exe $fakeExe `
                    -CallerName 'Test' -WarningAction SilentlyContinue
                ($env:Path -split ';') | Should -Contain $links
            }
            finally {
                $env:Path = $savedPath
            }
        }
    }

    It 'maps -Scope user to Install-WinGetPackage -Scope User, patches PATH, and warns when the exe is missing' {
        InModuleScope ScrewCitySoftware.PwshProfile {
            Mock Import-ModuleSafe { }
            Mock Install-WinGetPackage { [pscustomobject]@{ Status = 'Ok'; InstallerErrorCode = 0 } }

            $fakeExe = 'sc-not-a-real-exe-xyz.exe'
            $pathDir = Join-Path ([System.IO.Path]::GetTempPath()) ('sc-pathdir-' + [guid]::NewGuid())
            $savedPath = $env:Path
            try {
                Install-WingetPackageSafe -Id 'Some.Package' -Exe $fakeExe -PathDir $pathDir `
                    -Scope user -CallerName 'Test' -WarningVariable w -WarningAction SilentlyContinue

                Should -Invoke Install-WinGetPackage -Times 1 -Exactly -ParameterFilter {
                    $Id -eq 'Some.Package' -and $Source -eq 'winget' -and
                    $Mode -eq 'Silent' -and $MatchOption -eq 'Equals' -and $Scope -eq 'User'
                }
                # Session PATH patched so the (would-be) exe resolves immediately.
                $env:Path | Should -BeLike "*$pathDir*"
                # Ground-truth recheck failed (fake exe), so a diagnostic warning was emitted.
                $w | Should -Not -BeNullOrEmpty
            }
            finally {
                $env:Path = $savedPath
            }
        }
    }
}
