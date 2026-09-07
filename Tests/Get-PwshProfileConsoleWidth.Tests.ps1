#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
}

Describe 'Get-PwshProfileConsoleWidth' {
    It 'returns a positive width even under a redirected/non-interactive host' {
        # $Host.UI.RawUI.WindowSize is exactly the kind of thing that throws or returns something
        # useless under Pester's host, which is the case this fallback exists for.
        InModuleScope $script:Module {
            Get-PwshProfileConsoleWidth | Should -BeGreaterThan 0
        }
    }
}
