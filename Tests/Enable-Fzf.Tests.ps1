#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
}

Describe 'Enable-Fzf' {
    BeforeEach {
        # Run each substep body inline (no spinner) and never touch winget.
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Mock -ModuleName $script:Module Install-WingetPackageSafe { }
        Mock -ModuleName $script:Module Import-ModuleSafe { }
        # Pretend fzf.exe is present so the Initialize guard passes (no install needed).
        Mock -ModuleName $script:Module Get-Command { $true } -ParameterFilter { $Name -eq 'fzf.exe' }

        # These env vars are process-global; snapshot and clear so assertions are clean.
        $script:savedOpts  = $env:FZF_DEFAULT_OPTS
        $script:savedCtrlT = $env:FZF_CTRL_T_OPTS
        $script:savedPsfzf = $env:_PSFZF_FZF_DEFAULT_OPTS
        $env:FZF_DEFAULT_OPTS        = $null
        $env:FZF_CTRL_T_OPTS         = $null
        $env:_PSFZF_FZF_DEFAULT_OPTS = $null
    }

    AfterEach {
        $env:FZF_DEFAULT_OPTS        = $script:savedOpts
        $env:FZF_CTRL_T_OPTS         = $script:savedCtrlT
        $env:_PSFZF_FZF_DEFAULT_OPTS = $script:savedPsfzf
    }

    It 'sets FZF_DEFAULT_OPTS to the --ansi baseline on a bare call' {
        Enable-Fzf
        $env:FZF_DEFAULT_OPTS | Should -Be '--ansi'
    }

    It 'folds --color into FZF_DEFAULT_OPTS alongside --ansi' {
        Enable-Fzf -Colors 'pointer:#c9aaff'
        $env:FZF_DEFAULT_OPTS | Should -Be '--ansi --color=pointer:#c9aaff'
    }

    It 'folds --style into FZF_DEFAULT_OPTS unconditionally (no version gate)' {
        Enable-Fzf -Style full
        $env:FZF_DEFAULT_OPTS | Should -Be '--ansi --style=full'
    }

    It 'scopes the preview to FZF_CTRL_T_OPTS and never leaks it into the global opts' {
        Enable-Fzf -PreviewCommand 'bat {}'
        $env:FZF_CTRL_T_OPTS  | Should -Be "--preview 'bat {}'"
        $env:FZF_DEFAULT_OPTS | Should -Be '--ansi'
    }

    It 'sizes the PSFzf widgets via _PSFZF_FZF_DEFAULT_OPTS, leaving the global opts height-free' {
        Enable-Fzf -Colors 'pointer:#c9aaff' -Height '100%'
        # The PSFzf-only opts carry the base plus the height; the global opts stay height-free so a
        # bare fzf keeps its alternate-screen fullscreen.
        $env:_PSFZF_FZF_DEFAULT_OPTS | Should -Be '--ansi --color=pointer:#c9aaff --height=100%'
        $env:FZF_DEFAULT_OPTS        | Should -Be '--ansi --color=pointer:#c9aaff'
    }

    It 'leaves _PSFZF_FZF_DEFAULT_OPTS untouched when no -Height is given' {
        Enable-Fzf
        $env:_PSFZF_FZF_DEFAULT_OPTS | Should -BeNullOrEmpty
    }

    It 'does not import PSFzf when only -GitKeyBindings is requested and git is absent' {
        Mock -ModuleName $script:Module Get-Command { $null } -ParameterFilter { $Name -eq 'git' }
        Enable-Fzf -GitKeyBindings
        Should -Invoke -ModuleName $script:Module Import-ModuleSafe -Times 0 -Exactly
    }

    It 'imports PSFzf when a key-binding chord is requested' {
        Enable-Fzf -ProviderChord 'Ctrl+t'
        Should -Invoke -ModuleName $script:Module Import-ModuleSafe -Times 1 -Exactly
    }
}
