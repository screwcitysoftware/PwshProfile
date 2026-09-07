#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
}

Describe 'Enable-Ripgrep' {
    BeforeEach {
        # Run each substep body inline (no spinner) and never touch winget. The completer text from
        # `rg --generate complete-powershell` is swallowed (Invoke-InGlobalScope mocked), and a global
        # `rg` shim stands in for the exe so the call works without ripgrep installed.
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Mock -ModuleName $script:Module Install-WingetPackageSafe { }
        Mock -ModuleName $script:Module Invoke-InGlobalScope { }
        function global:rg { 'Register-ArgumentCompleter -Native -CommandName ''rg'' -ScriptBlock { }' }
    }

    AfterEach {
        Remove-Item Function:global:rg -ErrorAction SilentlyContinue
    }

    It 'installs the MSVC ripgrep portable' {
        Mock -ModuleName $script:Module Test-CommandAvailable { $true } -ParameterFilter { $Name -eq 'rg.exe' }
        Enable-Ripgrep
        Should -Invoke -ModuleName $script:Module Install-WingetPackageSafe -Times 1 -Exactly `
            -ParameterFilter { $Id -eq 'BurntSushi.ripgrep.MSVC' -and $Exe -eq 'rg.exe' }
    }

    It 'registers ripgrep''s own completer in global scope' {
        # Global scope, not Invoke-Expression: a module function that Invoke-Expressions the completer
        # tags every helper it defines with the module name, leaking them into Get-Command -Module.
        Mock -ModuleName $script:Module Test-CommandAvailable { $true } -ParameterFilter { $Name -eq 'rg.exe' }
        Enable-Ripgrep
        Should -Invoke -ModuleName $script:Module Invoke-InGlobalScope -Times 1 -Exactly `
            -ParameterFilter { $Expression -match 'Register-ArgumentCompleter' }
    }

    It 'does nothing when rg.exe is not on PATH' {
        # Failure tolerance: a failed install already warned from Install-WingetPackageSafe, so
        # Initialize is skipped rather than throwing out of profile startup.
        Mock -ModuleName $script:Module Test-CommandAvailable { $null }
        { Enable-Ripgrep } | Should -Not -Throw
        Should -Invoke -ModuleName $script:Module Invoke-InGlobalScope -Times 0 -Exactly
    }
}
