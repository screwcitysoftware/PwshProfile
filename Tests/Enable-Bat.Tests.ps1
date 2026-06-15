#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
}

Describe 'Enable-Bat' {
    BeforeEach {
        # Run each substep body inline (no spinner) and never touch winget. The completer text from
        # `bat --completion ps1` is captured by the Invoke-InGlobalScope mock (so nothing actually
        # registers), and a global `bat` shim emits a registration line shaped like bat's real output
        # so the -CommandName -replace can be exercised without bat installed.
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Mock -ModuleName $script:Module Install-WingetPackageSafe { }
        $script:registered = $null
        Mock -ModuleName $script:Module Invoke-InGlobalScope { $script:registered = $Expression }
        function global:bat { "Register-ArgumentCompleter -Native -CommandName 'bat' -ScriptBlock { }" }

        # These env vars are process-global; snapshot and clear so assertions are clean.
        $script:savedTheme = $env:BAT_THEME
        $script:savedStyle = $env:BAT_STYLE
        $env:BAT_THEME = $null
        $env:BAT_STYLE = $null
    }

    AfterEach {
        Remove-Item Function:global:bat -ErrorAction SilentlyContinue
        Remove-Item Alias:global:cat -ErrorAction SilentlyContinue
        $env:BAT_THEME = $script:savedTheme
        $env:BAT_STYLE = $script:savedStyle
    }

    It 'sets the theme and style and registers a bat-only completer without -ReplaceCat' {
        Mock -ModuleName $script:Module Get-Command { $true } -ParameterFilter { $Name -eq 'bat.exe' }
        Enable-Bat -Theme Dracula -Style 'plain'
        $env:BAT_THEME      | Should -Be 'Dracula'
        $env:BAT_STYLE      | Should -Be 'plain'
        $script:registered  | Should -Match "-CommandName 'bat'"
        $script:registered  | Should -Not -Match "'cat'"
    }

    It 'extends the completer to the cat alias and aliases cat -> bat under -ReplaceCat' {
        Mock -ModuleName $script:Module Get-Command { $true } -ParameterFilter { $Name -eq 'bat.exe' }
        Enable-Bat -Theme Dracula -ReplaceCat
        $script:registered          | Should -Match "-CommandName 'bat', 'cat'"
        (Get-Alias cat).Definition  | Should -Be 'bat.exe'
    }
}
