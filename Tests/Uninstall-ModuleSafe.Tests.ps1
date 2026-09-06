#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
}

Describe 'Uninstall-ModuleSafe' {

    It 'short-circuits and returns $true without removing anything when the module is already gone' {
        InModuleScope ScrewCitySoftware.PwshProfile {
            Mock Test-ModuleAvailable { $false }
            Mock Remove-Module { }
            Mock Uninstall-PSResource { }
            $r = Uninstall-ModuleSafe -Name 'NotReallyInstalled' -CallerName 'Test'
            $r | Should -BeTrue
            Should -Invoke Remove-Module -Times 0 -Exactly
            Should -Invoke Uninstall-PSResource -Times 0 -Exactly
        }
    }

    It 'removes a present module from the session before uninstalling it, and returns $true on success' {
        InModuleScope ScrewCitySoftware.PwshProfile {
            $script:probeCount = 0
            Mock Test-ModuleAvailable {
                $script:probeCount++
                # Present going in, gone once uninstalled -- the shape of a real removal.
                $script:probeCount -eq 1
            }
            Mock Remove-Module { }
            Mock Uninstall-PSResource { }
            $r = Uninstall-ModuleSafe -Name 'SomeModule' -CallerName 'Test'
            $r | Should -BeTrue
            Should -Invoke Remove-Module -Times 1 -Exactly -ParameterFilter { $Name -eq 'SomeModule' }
            Should -Invoke Uninstall-PSResource -Times 1 -Exactly -ParameterFilter { $Name -eq 'SomeModule' }
        }
    }

    It 'warns and returns $false when Uninstall-PSResource throws' {
        InModuleScope ScrewCitySoftware.PwshProfile {
            Mock Test-ModuleAvailable { $true }
            Mock Remove-Module { }
            Mock Uninstall-PSResource { throw 'boom' }
            $r = Uninstall-ModuleSafe -Name 'SomeModule' -CallerName 'Test' `
                -WarningVariable w -WarningAction SilentlyContinue
            $r | Should -BeFalse
            $w | Should -Not -BeNullOrEmpty
        }
    }

    It 'warns and returns $false when the module is still available afterward' {
        InModuleScope ScrewCitySoftware.PwshProfile {
            Mock Test-ModuleAvailable { $true }
            Mock Remove-Module { }
            Mock Uninstall-PSResource { }
            $r = Uninstall-ModuleSafe -Name 'SomeModule' -CallerName 'Test' `
                -WarningVariable w -WarningAction SilentlyContinue
            $r | Should -BeFalse
            $w | Should -Not -BeNullOrEmpty
        }
    }
}
