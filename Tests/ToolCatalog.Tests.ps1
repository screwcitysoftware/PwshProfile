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
        @($sections['WinGet'].Token) | Should -Be @('Zoxide', 'Fzf', 'Fnm', 'Xh', 'Jq', 'Bat', 'Fd', 'Less')
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

    It '-DefaultEnabled returns the non-winget tokens (clean-install default-on set)' {
        $def = & (Get-Module $script:Module) { Get-PwshProfileToolCatalog -DefaultEnabled }
        @($def) | Should -Be @('PSReadLine', 'TerminalIcons', 'PoshGit', 'Completions')
    }

    It 'the -Enable ValidateSet on Initialize-PwshProfile matches the catalog tokens (anti-drift)' {
        $tokens = & (Get-Module $script:Module) { Get-PwshProfileToolCatalog -Token }
        $set = (Get-Command Initialize-PwshProfile).Parameters['Enable'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } |
            Select-Object -First 1
        $set | Should -Not -BeNullOrEmpty
        @($set.ValidValues) | Should -Be @($tokens)
    }
}
