#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
}

Describe 'Enable-Uv' {
    BeforeEach {
        # Run each substep body inline (no spinner) and never touch winget. The completer text is
        # swallowed (Invoke-InGlobalScope mocked), and global `uv`/`uvx` shims stand in for the exes
        # so the calls work without uv installed.
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Mock -ModuleName $script:Module Install-WingetPackageSafe { }
        Mock -ModuleName $script:Module Invoke-InGlobalScope { }
        function global:uv { 'Register-ArgumentCompleter -Native -CommandName ''uv'' -ScriptBlock { }' }
        function global:uvx { 'Register-ArgumentCompleter -Native -CommandName ''uvx'' -ScriptBlock { }' }
    }

    AfterEach {
        Remove-Item Function:global:uv -ErrorAction SilentlyContinue
        Remove-Item Function:global:uvx -ErrorAction SilentlyContinue
    }

    It 'installs the uv portable' {
        Mock -ModuleName $script:Module Test-CommandAvailable { $true } -ParameterFilter { $Name -eq 'uv.exe' }
        Enable-Uv
        Should -Invoke -ModuleName $script:Module Install-WingetPackageSafe -Times 1 -Exactly `
            -ParameterFilter { $Id -eq 'astral-sh.uv' -and $Exe -eq 'uv.exe' }
    }

    It 'registers uvx''s completer in global scope' {
        # Global scope, not Invoke-Expression: a module function that Invoke-Expressions the completer
        # tags every helper it defines with the module name, leaking them into Get-Command -Module.
        Mock -ModuleName $script:Module Test-CommandAvailable { $true } -ParameterFilter { $Name -eq 'uv.exe' }
        Enable-Uv
        Should -Invoke -ModuleName $script:Module Invoke-InGlobalScope -Times 1 -Exactly `
            -ParameterFilter { $Expression -match "-CommandName 'uvx'" }
    }

    It 'does NOT register uv''s own completer' {
        # Deliberate, and pinned so it can't drift back silently. A completer binds to a command name,
        # so uv would need its own registration -- but uv's is ~754 KB of generated PowerShell costing
        # ~244ms of every startup (vs ~49ms for uvx), which made it the most expensive single step in
        # the profile. See Enable-Uv's .NOTES before changing this.
        Mock -ModuleName $script:Module Test-CommandAvailable { $true } -ParameterFilter { $Name -eq 'uv.exe' }
        Enable-Uv
        Should -Invoke -ModuleName $script:Module Invoke-InGlobalScope -Times 1 -Exactly
        Should -Invoke -ModuleName $script:Module Invoke-InGlobalScope -Times 0 -Exactly `
            -ParameterFilter { $Expression -match "-CommandName 'uv'" }
    }

    It 'does nothing when uv.exe is not on PATH' {
        # Failure tolerance: a failed install already warned from Install-WingetPackageSafe, so
        # Initialize is skipped rather than throwing out of profile startup.
        Mock -ModuleName $script:Module Test-CommandAvailable { $null }
        { Enable-Uv } | Should -Not -Throw
        Should -Invoke -ModuleName $script:Module Invoke-InGlobalScope -Times 0 -Exactly
    }
}
