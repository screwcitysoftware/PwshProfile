#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
}

Describe 'Enable-Xh' {
    BeforeEach {
        # Run each substep body inline (no spinner) and never touch winget. The completer text is
        # swallowed (Invoke-InGlobalScope mocked); global shims stand in for the exes, returning the
        # -CommandName line the -replace widening is coupled to.
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Mock -ModuleName $script:Module Install-WingetPackageSafe { }
        Mock -ModuleName $script:Module Invoke-InGlobalScope { }
        function global:xh { "Register-ArgumentCompleter -Native -CommandName 'xh' -ScriptBlock { }" }
        function global:xhs { "Register-ArgumentCompleter -Native -CommandName 'xhs' -ScriptBlock { }" }

        Remove-Alias -Name http -Scope Global -Force -ErrorAction SilentlyContinue
        Remove-Alias -Name https -Scope Global -Force -ErrorAction SilentlyContinue
    }

    AfterEach {
        Remove-Item Function:global:xh -ErrorAction SilentlyContinue
        Remove-Item Function:global:xhs -ErrorAction SilentlyContinue
        Remove-Alias -Name http -Scope Global -Force -ErrorAction SilentlyContinue
        Remove-Alias -Name https -Scope Global -Force -ErrorAction SilentlyContinue
    }

    It 'registers completion for xh and xhs only, claiming no names, by default' {
        Mock -ModuleName $script:Module Test-CommandAvailable { $true } -ParameterFilter { $Name -in @('xh.exe', 'xhs.exe') }
        Enable-Xh
        Get-Alias http -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Alias https -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        # The completers still register -- for the tools' own names, unwidened.
        Should -Invoke -ModuleName $script:Module Invoke-InGlobalScope -Times 1 -Exactly `
            -ParameterFilter { $Expression -match "-CommandName 'xh'" -and $Expression -notmatch "'http'" }
        Should -Invoke -ModuleName $script:Module Invoke-InGlobalScope -Times 1 -Exactly `
            -ParameterFilter { $Expression -match "-CommandName 'xhs'" -and $Expression -notmatch "'https'" }
    }

    It 'aliases http/https and widens both completers under -ReplaceHttp' {
        Mock -ModuleName $script:Module Test-CommandAvailable { $true } -ParameterFilter { $Name -in @('xh.exe', 'xhs.exe') }
        Enable-Xh -ReplaceHttp
        (Get-Alias http).Definition | Should -Be 'xh.exe'
        (Get-Alias https).Definition | Should -Be 'xhs.exe'
        # PowerShell completers don't follow aliases, so the -CommandName literal is widened to cover
        # each alias. A completion registered for `http` would be meaningless without the alias, which
        # is why the widening rides the same switch.
        Should -Invoke -ModuleName $script:Module Invoke-InGlobalScope -Times 1 -Exactly `
            -ParameterFilter { $Expression -match "-CommandName 'xh', 'http'" }
        Should -Invoke -ModuleName $script:Module Invoke-InGlobalScope -Times 1 -Exactly `
            -ParameterFilter { $Expression -match "-CommandName 'xhs', 'https'" }
    }

    It 'installs the xh portable' {
        Mock -ModuleName $script:Module Test-CommandAvailable { $true } -ParameterFilter { $Name -in @('xh.exe', 'xhs.exe') }
        Enable-Xh
        Should -Invoke -ModuleName $script:Module Install-WingetPackageSafe -Times 1 -Exactly `
            -ParameterFilter { $Id -eq 'ducaale.xh' -and $Exe -eq 'xh.exe' }
    }

    It 'skips the xhs half when only xh.exe resolves' {
        # xh and xhs are probed independently, so a package that shipped only one still wires that one.
        Mock -ModuleName $script:Module Test-CommandAvailable { $true } -ParameterFilter { $Name -eq 'xh.exe' }
        Mock -ModuleName $script:Module Test-CommandAvailable { $null } -ParameterFilter { $Name -eq 'xhs.exe' }
        Enable-Xh -ReplaceHttp
        (Get-Alias http).Definition | Should -Be 'xh.exe'
        Get-Alias https -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Should -Invoke -ModuleName $script:Module Invoke-InGlobalScope -Times 1 -Exactly
    }

    It 'does nothing when neither exe is on PATH' {
        Mock -ModuleName $script:Module Test-CommandAvailable { $null }
        { Enable-Xh -ReplaceHttp } | Should -Not -Throw
        Should -Invoke -ModuleName $script:Module Invoke-InGlobalScope -Times 0 -Exactly
        Get-Alias http -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }
}
