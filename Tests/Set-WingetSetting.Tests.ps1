#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# These suites mock the Microsoft.WinGet.Client cmdlets, which must exist in the session to be
# mockable. Skip wholesale when the module isn't installed (matches the NerdFonts-gated suites).
BeforeDiscovery {
    $script:HasWinGetClient = [bool](Get-Module -ListAvailable -Name Microsoft.WinGet.Client)
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    Import-Module Microsoft.WinGet.Client -ErrorAction SilentlyContinue
    $script:Module = 'ScrewCitySoftware.PwshProfile'
}

Describe 'Set-WingetSetting' -Skip:(-not $HasWinGetClient) {
    BeforeEach {
        InModuleScope ScrewCitySoftware.PwshProfile {
            Mock Import-ModuleSafe { }
            # Current user settings: $schema + an unmanaged sibling key under visual we must preserve.
            Mock Get-WinGetUserSetting {
                @{
                    '$schema' = 'https://aka.ms/winget-settings.schema.json'
                    visual    = @{ progressBar = 'rainbow'; enableSixels = $true }
                }
            }
            Mock Set-WinGetUserSetting { }
        }
    }

    It 'merges the requested keys into their nested objects' {
        InModuleScope ScrewCitySoftware.PwshProfile {
            Set-WingetSetting -Scope user -ProgressBar accent
            Should -Invoke Set-WinGetUserSetting -Times 1 -Exactly -ParameterFilter {
                $UserSettings.installBehavior.preferences.scope -eq 'user' -and
                $UserSettings.visual.progressBar -eq 'accent'
            }
        }
    }

    It 'preserves $schema and unmanaged sibling keys' {
        InModuleScope ScrewCitySoftware.PwshProfile {
            Set-WingetSetting -ProgressBar retro
            Should -Invoke Set-WinGetUserSetting -Times 1 -Exactly -ParameterFilter {
                $UserSettings.'$schema' -eq 'https://aka.ms/winget-settings.schema.json' -and
                $UserSettings.visual.enableSixels -eq $true -and
                $UserSettings.visual.progressBar -eq 'retro'
            }
        }
    }

    It 'changes only the parameters that were passed' {
        InModuleScope ScrewCitySoftware.PwshProfile {
            Set-WingetSetting -ProgressBar retro
            Should -Invoke Set-WinGetUserSetting -Times 1 -Exactly -ParameterFilter {
                -not $UserSettings.ContainsKey('installBehavior')
            }
        }
    }

    It 'writes a $false bool rather than skipping it' {
        InModuleScope ScrewCitySoftware.PwshProfile {
            Set-WingetSetting -AnonymizePath $true -DisableInstallNote $false
            Should -Invoke Set-WinGetUserSetting -Times 1 -Exactly -ParameterFilter {
                $UserSettings.visual.anonymizeDisplayedPaths -eq $true -and
                $UserSettings.installBehavior.disableInstallNotes -eq $false
            }
        }
    }

    It 'does not write under -WhatIf' {
        InModuleScope ScrewCitySoftware.PwshProfile {
            Set-WingetSetting -Scope machine -WhatIf
            Should -Invoke Set-WinGetUserSetting -Times 0 -Exactly
        }
    }

    It 'warns instead of throwing when the module is unavailable' {
        InModuleScope ScrewCitySoftware.PwshProfile {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Set-WinGetUserSetting' }
            { Set-WingetSetting -Scope user -WarningAction SilentlyContinue } | Should -Not -Throw
            Should -Invoke Set-WinGetUserSetting -Times 0 -Exactly
        }
    }
}

Describe 'Get-WingetSettingDefault' -Skip:(-not $HasWinGetClient) {
    BeforeEach {
        InModuleScope ScrewCitySoftware.PwshProfile { Mock Import-ModuleSafe { } }
    }

    It 'returns explicit file values where set and falls back otherwise' {
        InModuleScope ScrewCitySoftware.PwshProfile {
            # Only progressBar + scope are set; anonymize / install-notes fall back.
            Mock Get-WinGetUserSetting {
                @{
                    visual          = @{ progressBar = 'retro' }
                    installBehavior = @{ preferences = @{ scope = 'machine' } }
                }
            }
            $d = Get-WingetSettingDefault
            $d.ProgressBar | Should -Be 'retro'
            $d.Scope | Should -Be 'machine'
            $d.AnonymizePath | Should -BeTrue       # fallback
            $d.DisableInstallNote | Should -BeFalse  # fallback
        }
    }

    It 'returns all module fallbacks for empty user settings' {
        InModuleScope ScrewCitySoftware.PwshProfile {
            Mock Get-WinGetUserSetting { @{} }
            $d = Get-WingetSettingDefault
            $d.Scope | Should -Be 'user'
            $d.ProgressBar | Should -Be 'rainbow'
            $d.AnonymizePath | Should -BeTrue
            $d.DisableInstallNote | Should -BeFalse
        }
    }
}

Describe 'Get-WingetSettingRecommended' {
    It 'is the source of truth for the recommended winget values' {
        InModuleScope ScrewCitySoftware.PwshProfile {
            $r = Get-WingetSettingRecommended
            $r.Scope | Should -Be 'user'
            $r.ProgressBar | Should -Be 'rainbow'
            $r.AnonymizePath | Should -BeTrue
            $r.DisableInstallNote | Should -BeFalse
        }
    }
}
