#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
}

AfterAll {
    # Remove any global functions the tests defined so they don't leak between runs.
    foreach ($name in '__scs_test_global', '__scs_test_noprefix', '__scs_test_surface') {
        if (Test-Path "Function:\$name") { Remove-Item "Function:\$name" -Force }
    }
}

Describe 'Invoke-InGlobalScope' {
    It 'defines functions in the global scope with no module attribution' {
        InModuleScope $script:Module { Invoke-InGlobalScope 'function global:__scs_test_global { 42 }' }

        $cmd = Get-Command __scs_test_global -ErrorAction SilentlyContinue
        $cmd | Should -Not -BeNullOrEmpty
        # The point of the helper: the function is global, not tagged to the module.
        $cmd.Source | Should -BeNullOrEmpty
        $cmd.ModuleName | Should -BeNullOrEmpty
        & __scs_test_global | Should -Be 42
    }

    It 'lands functions globally even without a global: prefix' {
        InModuleScope $script:Module { Invoke-InGlobalScope 'function __scs_test_noprefix { 7 }' }

        $cmd = Get-Command __scs_test_noprefix -ErrorAction SilentlyContinue
        $cmd | Should -Not -BeNullOrEmpty
        $cmd.Source | Should -BeNullOrEmpty
        & __scs_test_noprefix | Should -Be 7
    }

    It 'does not add the defined function to the module command surface' {
        # Self-contained: define a fresh global function via the helper, then prove it's unattributed
        # AND absent from the module's command surface (independent of the other It blocks).
        InModuleScope $script:Module { Invoke-InGlobalScope 'function global:__scs_test_surface { 1 }' }
        try {
            (Get-Command __scs_test_surface).Source | Should -BeNullOrEmpty
            (Get-Command -Module $script:Module).Name | Should -Not -Contain '__scs_test_surface'
        }
        finally {
            if (Test-Path 'Function:\__scs_test_surface') { Remove-Item 'Function:\__scs_test_surface' -Force }
        }
    }
}
