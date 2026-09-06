#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
}

Describe 'Get-PwshProfileToolCatalog' {
    It 'groups features as Core then WinGet' {
        $sections = & (Get-Module $script:Module) { Get-PwshProfileToolCatalog }
        @($sections.Keys) | Should -Be @('Core', 'WinGet')
    }

    It 'the WinGet group is exactly the winget-install entries' {
        $sections = & (Get-Module $script:Module) { Get-PwshProfileToolCatalog }
        @($sections['WinGet'] | Where-Object { $_.Install -ne 'winget' }) | Should -BeNullOrEmpty
        @($sections['WinGet'].Token) | Should -Be @('Zoxide', 'Fzf', 'Fnm', 'Xh', 'Jq', 'Bat', 'Fd', 'Ripgrep', 'Less', 'Lazygit')
    }

    It 'the Core group is exactly the non-winget entries' {
        $sections = & (Get-Module $script:Module) { Get-PwshProfileToolCatalog }
        @($sections['Core'] | Where-Object { $_.Install -eq 'winget' }) | Should -BeNullOrEmpty
        @($sections['Core'].Token) | Should -Be @('PSReadLine', 'TerminalIcons', 'PoshGit', 'Completions')
    }

    It 'every feature row carries a Label, Token, and a valid Install kind' {
        $sections = & (Get-Module $script:Module) { Get-PwshProfileToolCatalog }
        foreach ($key in $sections.Keys) {
            foreach ($f in $sections[$key]) {
                $f.Label | Should -Not -BeNullOrEmpty
                $f.Token | Should -Not -BeNullOrEmpty
                $f.Install | Should -BeIn @('winget', 'module', 'none')
            }
        }
    }

    It 'includes jq among the WinGet tokens' {
        $tokens = & (Get-Module $script:Module) { Get-PwshProfileToolCatalog -Token }
        $tokens | Should -Contain 'Jq'
    }

    It 'includes ripgrep among the WinGet tokens' {
        $tokens = & (Get-Module $script:Module) { Get-PwshProfileToolCatalog -Token }
        $tokens | Should -Contain 'Ripgrep'
    }

    It 'includes lazygit among the WinGet tokens' {
        $tokens = & (Get-Module $script:Module) { Get-PwshProfileToolCatalog -Token }
        $tokens | Should -Contain 'Lazygit'
    }

    It 'has no tool-selection parameters left on Initialize-PwshProfile' {
        # Every tool always runs. This is a tripwire against reintroducing an opt-in parameter without
        # also restoring the catalog<->ValidateSet anti-drift check that used to guard it.
        $p = (Get-Command Initialize-PwshProfile).Parameters
        $p.ContainsKey('Enable') | Should -BeFalse
        $p.ContainsKey('EnableAll') | Should -BeFalse
    }

    It 'gives every token a unique, non-empty label' {
        $sections = & (Get-Module $script:Module) { Get-PwshProfileToolCatalog }
        $rows = @(foreach ($k in $sections.Keys) { $sections[$k] })
        @($rows.Token | Sort-Object -Unique).Count | Should -Be $rows.Count
        # Labels key the wizard's selection prompts back to tokens, so they must not collide either.
        @($rows.Label | Sort-Object -Unique).Count | Should -Be $rows.Count
    }
}
