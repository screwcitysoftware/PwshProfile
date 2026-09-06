#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
}

Describe 'Show-PwshProfileChord' {
    BeforeEach {
        # Capture the panel text instead of rendering it. -RemoveParameterType Color: the mock
        # doesn't replicate the string->Color transform.
        $script:Panel = $null
        Mock -ModuleName $script:Module Format-SpectrePanel -RemoveParameterType 'Color' {
            $script:Panel = "$Data"
        }
        # Fixed so the wrap-width math below is deterministic regardless of the host running the suite.
        Mock -ModuleName $script:Module Get-PwshProfileConsoleWidth { 80 }
    }

    It 'lists every unconditional catalog chord by default' {
        Show-PwshProfileChord
        # Ctrl+G is the one row a bare call must NOT show -- covered by its own test below.
        $chords = InModuleScope $script:Module { (Get-PwshProfileChordCatalog).Chord } |
            Where-Object { $_ -notlike 'Ctrl+G*' }
        foreach ($chord in $chords) {
            $script:Panel | Should -Match ([regex]::Escape($chord))
        }
    }

    It 'hides the Ctrl+G row by default (a fresh install has it off)' {
        Show-PwshProfileChord
        $script:Panel | Should -Not -Match 'Ctrl\+G'
    }

    It 'shows the Ctrl+G row when -FzfGitKeyBindings is on and git is available' {
        Mock -ModuleName $script:Module Test-CommandAvailable { $true } -ParameterFilter { $Name -eq 'git' }
        Show-PwshProfileChord -FzfGitKeyBindings
        $script:Panel | Should -Match 'Ctrl\+G'
    }

    It 'still hides the Ctrl+G row when -FzfGitKeyBindings is on but git is not available' {
        # Mirrors Enable-Fzf's own exact gate -- it drops the chords on a git-less machine too.
        Mock -ModuleName $script:Module Test-CommandAvailable { $false } -ParameterFilter { $Name -eq 'git' }
        Show-PwshProfileChord -FzfGitKeyBindings
        $script:Panel | Should -Not -Match 'Ctrl\+G'
    }

    It 'shows the configured tab chord literally when it differs from the default' {
        Show-PwshProfileChord -FzfTabChord 'Ctrl+j'
        $script:Panel | Should -Match ([regex]::Escape('[link=https://github.com/kelleyma49/PSFzf]Ctrl+j[/]'))
        # The row's chord cell must show only the literal chord -- Owner's descriptive text still
        # mentions 'Ctrl+Spacebar' as the setting's default, which is fine, just not as the chord cell.
        $script:Panel | Should -Not -Match 'Ctrl\+Spacebar / Ctrl\+@'
    }

    It 'hides the tab-completion row entirely when -FzfTabChord is empty' {
        # Enable-Fzf treats an empty chord as unbound.
        Show-PwshProfileChord -FzfTabChord ''
        $script:Panel | Should -Not -Match 'fzf picker over what Tab would complete'
    }

    It 'renders exactly one panel' {
        Show-PwshProfileChord
        Should -Invoke -ModuleName $script:Module Format-SpectrePanel -Times 1 -Exactly
    }

    It 'returns nothing' {
        Show-PwshProfileChord | Should -BeNullOrEmpty
    }

    It 'wraps long detail text at the console width instead of running past it' {
        Show-PwshProfileChord
        # Strip Spectre markup before measuring: a chord line now carries an invisible
        # "[link=...]...[/]" span, which inflates the raw string length without affecting what
        # actually renders -- exactly like a real terminal, which doesn't count markup toward width.
        foreach ($line in ($script:Panel -split "`r?`n")) {
            ($line -replace '\[[^\]]*\]', '').Length | Should -BeLessOrEqual 80
        }
    }

    It 'links each chord to its owning project' {
        Show-PwshProfileChord
        $script:Panel | Should -Match ([regex]::Escape('[link=https://github.com/kelleyma49/PSFzf]Ctrl+T[/]'))
        $script:Panel | Should -Match ([regex]::Escape('[link=https://github.com/PowerShell/PSReadLine]Tab[/]'))
    }

    It 'hang-indents a wrapped continuation under the chord column, not column 0' {
        Show-PwshProfileChord
        # Ctrl+R's Note is long enough at width 80 to wrap onto more than one line; a later fragment of
        # that same sentence (not its first word) must still start indented, never flush against the
        # left margin the way the terminal's own wrap left it before this fix.
        $continuation = @($script:Panel -split "`r?`n") | Where-Object { $_ -match 'ForwardSearchHistory' }
        $continuation | Should -Not -BeNullOrEmpty
        $continuation | Should -Match '^\s{4,}\S'
    }
}
