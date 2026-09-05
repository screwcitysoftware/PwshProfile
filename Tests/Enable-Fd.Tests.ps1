#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
}

Describe 'Enable-Fd' {
    BeforeEach {
        # Run each substep body inline (no spinner) and never touch winget. The completer text from
        # `fd --gen-completions powershell` is swallowed (Invoke-InGlobalScope mocked), and a global
        # `fd` shim stands in for the exe so the call works without fd installed.
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Mock -ModuleName $script:Module Install-WingetPackageSafe { }
        Mock -ModuleName $script:Module Invoke-InGlobalScope { }
        function global:fd { '' }

        # These env vars are process-global; snapshot and clear so assertions are clean.
        $script:savedLs       = $env:LS_COLORS
        $script:savedDefault  = $env:FZF_DEFAULT_COMMAND
        $script:savedCtrlT    = $env:FZF_CTRL_T_COMMAND
        $script:savedAltC     = $env:FZF_ALT_C_COMMAND
        $env:LS_COLORS           = $null
        $env:FZF_DEFAULT_COMMAND = $null
        $env:FZF_CTRL_T_COMMAND  = $null
        $env:FZF_ALT_C_COMMAND   = $null
    }

    AfterEach {
        Remove-Item Function:global:fd -ErrorAction SilentlyContinue
        $env:LS_COLORS           = $script:savedLs
        $env:FZF_DEFAULT_COMMAND = $script:savedDefault
        $env:FZF_CTRL_T_COMMAND  = $script:savedCtrlT
        $env:FZF_ALT_C_COMMAND   = $script:savedAltC
    }

    It 'colors fd and points a bare fzf at fd, without setting the dead FZF_CTRL_T_COMMAND' {
        Mock -ModuleName $script:Module Get-Command { $true } -ParameterFilter { $Name -in @('fd.exe', 'fzf.exe') }
        Enable-Fd -LsColors 'di=0' -IntegrateFzf
        $env:LS_COLORS           | Should -Be 'di=0'
        $env:FZF_DEFAULT_COMMAND | Should -Not -BeNullOrEmpty
        # fd's source command forces case-insensitive matching (PowerShell/Windows is).
        $env:FZF_DEFAULT_COMMAND | Should -Match '--ignore-case'
        $env:FZF_CTRL_T_COMMAND  | Should -BeNullOrEmpty
    }

    It 'points PSFzf''s Alt+C directory picker at fd, case-insensitively' {
        # Alt+C is the one PSFzf lookup that ignores FZF_DEFAULT_COMMAND and falls back to a built-in
        # `fd ... --fixed-strings .` that matches almost nothing on Windows, so Enable-Fd overrides it.
        Mock -ModuleName $script:Module Get-Command { $true } -ParameterFilter { $Name -in @('fd.exe', 'fzf.exe') }
        Enable-Fd -LsColors 'di=0' -IntegrateFzf
        $env:FZF_ALT_C_COMMAND | Should -Match '--ignore-case'
        $env:FZF_ALT_C_COMMAND | Should -Match '--type directory'
        # It must not carry the --fixed-strings fallback shape it exists to replace.
        $env:FZF_ALT_C_COMMAND | Should -Not -Match '--fixed-strings'
    }

    It 'leaves both fzf source commands unset when -IntegrateFzf is omitted' {
        Mock -ModuleName $script:Module Get-Command { $true } -ParameterFilter { $Name -eq 'fd.exe' }
        Enable-Fd -LsColors 'di=0'
        $env:FZF_DEFAULT_COMMAND | Should -BeNullOrEmpty
        $env:FZF_ALT_C_COMMAND   | Should -BeNullOrEmpty
    }
}
