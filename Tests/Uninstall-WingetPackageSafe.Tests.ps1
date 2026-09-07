#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Mocks Uninstall-WinGetPackage, which must exist in the session to be mockable.
BeforeDiscovery {
    $script:HasWinGetClient = [bool](Get-Module -ListAvailable -Name Microsoft.WinGet.Client)
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    Import-Module Microsoft.WinGet.Client -ErrorAction SilentlyContinue
    $script:Module = 'ScrewCitySoftware.PwshProfile'
}

Describe 'Uninstall-WingetPackageSafe' -Skip:(-not $HasWinGetClient) {

    It 'short-circuits and returns $true without loading the module when the exe is already gone' {
        InModuleScope ScrewCitySoftware.PwshProfile {
            Mock Import-ModuleSafe { }
            Mock Uninstall-WinGetPackage { }
            $fakeExe = 'sc-not-a-real-exe-' + [guid]::NewGuid() + '.exe'
            $r = Uninstall-WingetPackageSafe -Id 'x.y' -Exe $fakeExe -CallerName 'Test'
            $r | Should -BeTrue
            Should -Invoke Import-ModuleSafe -Times 0 -Exactly
            Should -Invoke Uninstall-WinGetPackage -Times 0 -Exactly
        }
    }

    It 'uninstalls a present package and returns $true when the exe is gone afterward' {
        InModuleScope ScrewCitySoftware.PwshProfile {
            Mock Import-ModuleSafe { }
            Mock Uninstall-WinGetPackage { }
            Mock Get-Command { [pscustomobject]@{ Name = $Name } } -ParameterFilter { $Name -eq 'Uninstall-WinGetPackage' }
            # The function probes $Exe twice — before (must look present) and after (must look gone).
            # A ParameterFilter can't tell those two calls apart, so count invocations instead.
            $script:probeCount = 0
            Mock Get-Command {
                $script:probeCount++
                if ($script:probeCount -eq 1) { [pscustomobject]@{ Name = $Name } } else { $null }
            } -ParameterFilter { $Name -eq 'pwsh.exe' }

            $r = Uninstall-WingetPackageSafe -Id 'vendor.tool' -Exe 'pwsh.exe' -CallerName 'Test'

            $r | Should -BeTrue
            Should -Invoke Uninstall-WinGetPackage -Times 1 -Exactly -ParameterFilter {
                $Id -eq 'vendor.tool' -and $Source -eq 'winget' -and $Mode -eq 'Silent'
            }
        }
    }

    It 'warns and returns $false when the exe is still resolvable afterward' {
        InModuleScope ScrewCitySoftware.PwshProfile {
            Mock Import-ModuleSafe { }
            Mock Uninstall-WinGetPackage { }
            # Every Get-Command call answers truthy: the exe "never leaves", simulating a failed removal.
            Mock Get-Command { [pscustomobject]@{ Name = $Name } }
            $r = Uninstall-WingetPackageSafe -Id 'vendor.tool' -Exe 'pwsh.exe' -CallerName 'Test' `
                -WarningVariable w -WarningAction SilentlyContinue
            $r | Should -BeFalse
            $w | Should -Not -BeNullOrEmpty
        }
    }
}
