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

    It 'records nothing when the tool was already present' {
        # The startup notice must fire only when startup genuinely installed something. A tool that
        # was already there is the normal case and has to stay silent.
        InModuleScope ScrewCitySoftware.PwshProfile {
            $script:StartupInstall.Clear()
            Mock Import-ModuleSafe { }
            Mock Install-WinGetPackage { }
            Install-WingetPackageSafe -Id 'x.y' -Exe 'pwsh.exe' -CallerName 'Test'
            $script:StartupInstall.Count | Should -Be 0
        }
    }

    It 'records a package it actually installed' {
        InModuleScope ScrewCitySoftware.PwshProfile {
            $script:StartupInstall.Clear()
            Mock Import-ModuleSafe { }
            Mock Install-WinGetPackage { [pscustomobject]@{ Status = 'Ok'; InstallerErrorCode = 0 } }
            # Absent going in, present coming out -- the shape of a real install.
            Mock Test-CommandAvailable { $false }
            # Default mock: the function also probes for the Install-WinGetPackage cmdlet itself, so a
            # filter-only mock leaves that call unmatched. Truthy for any name covers both.
            Mock Get-Command { [pscustomobject]@{ Name = $Name } }
            Install-WingetPackageSafe -Id 'vendor.newtool' -Exe 'newtool.exe' -PathDir 'C:\nope' -CallerName 'Test'
            @($script:StartupInstall) | Should -Be @('vendor.newtool')
            $script:StartupInstall.Clear()
        }
    }

    It 'records nothing under -Quiet, so the installer does not trip the notice' {
        InModuleScope ScrewCitySoftware.PwshProfile {
            $script:StartupInstall.Clear()
            Mock Import-ModuleSafe { }
            Mock Install-WinGetPackage { [pscustomobject]@{ Status = 'Ok'; InstallerErrorCode = 0 } }
            Mock Test-CommandAvailable { $false }
            # Default mock: the function also probes for the Install-WinGetPackage cmdlet itself, so a
            # filter-only mock leaves that call unmatched. Truthy for any name covers both.
            Mock Get-Command { [pscustomobject]@{ Name = $Name } }
            Install-WingetPackageSafe -Id 'vendor.newtool' -Exe 'newtool.exe' -PathDir 'C:\nope' `
                -CallerName 'Install-PwshProfile' -Quiet
            $script:StartupInstall.Count | Should -Be 0
        }
    }

    It 'records nothing when the install failed to produce the exe' {
        # It already warns in this case; recording it as installed would then claim a success that
        # did not happen, and send the user to re-run setup for the wrong reason.
        InModuleScope ScrewCitySoftware.PwshProfile {
            $script:StartupInstall.Clear()
            Mock Import-ModuleSafe { }
            Mock Install-WinGetPackage { [pscustomobject]@{ Status = 'Failed'; InstallerErrorCode = 1 } }
            Mock Test-CommandAvailable { $false }
            Install-WingetPackageSafe -Id 'vendor.missing' -Exe 'nosuchtool.exe' -PathDir 'C:\nope' `
                -CallerName 'Test' -WarningAction SilentlyContinue
            $script:StartupInstall.Count | Should -Be 0
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
