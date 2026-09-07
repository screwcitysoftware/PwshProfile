#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
}

Describe 'Get-PwshProfileChordCatalog' {
    It 'gives every row a Chord, an Action, an Owner, a Url, and declared Detail/Note/Setting' {
        InModuleScope $script:Module {
            foreach ($row in Get-PwshProfileChordCatalog) {
                @($row.PSObject.Properties.Name) | Sort-Object | Should -Be @('Action', 'Chord', 'Detail', 'Note', 'Owner', 'Setting', 'Url')
                $row.Chord | Should -Not -BeNullOrEmpty
                $row.Action | Should -Not -BeNullOrEmpty
                $row.Owner | Should -Not -BeNullOrEmpty
                $row.Url | Should -Match '^https://'
                # Detail and Note may be '', and Setting may be $null, but the properties must exist:
                # the suite runs under Set-StrictMode -Version Latest, where reading an omitted
                # property throws.
            }
        }
    }

    It 'names Setting on exactly the two rows whose activeness depends on it' {
        InModuleScope $script:Module {
            $rows = @(Get-PwshProfileChordCatalog)
            (@($rows | Where-Object { $_.Chord -like 'Ctrl+G*' })).Setting | Should -Be 'FzfGitKeyBindings'
            (@($rows | Where-Object { $_.Chord -like 'Ctrl+Spacebar*' })).Setting | Should -Be 'FzfTabChord'
            @($rows | Where-Object { $_.Chord -notlike 'Ctrl+G*' -and $_.Chord -notlike 'Ctrl+Spacebar*' } |
                    Where-Object { $null -ne $_.Setting }) | Should -BeNullOrEmpty
        }
    }

    It 'lists each chord once' {
        InModuleScope $script:Module {
            $rows = @(Get-PwshProfileChordCatalog)
            @($rows.Chord | Sort-Object -Unique).Count | Should -Be $rows.Count
        }
    }

    It 'links every row to exactly one of PSFzf or PSReadLine' {
        # Rows 1-5 are PSFzf's own PSReadLine integration (not the `fzf` binary, already linked
        # separately from the tool catalog); rows 6-9 are Initialize-PSReadline's own bindings.
        InModuleScope $script:Module {
            $urls = @((Get-PwshProfileChordCatalog).Url | Sort-Object -Unique)
            $urls | Should -Be (@(
                    'https://github.com/PowerShell/PSReadLine'
                    'https://github.com/kelleyma49/PSFzf'
                ) | Sort-Object)
        }
    }

    It 'hands each caller its own rows' {
        InModuleScope $script:Module {
            $first = @(Get-PwshProfileChordCatalog)
            $second = @(Get-PwshProfileChordCatalog)
            $first[0].Chord = 'mutated'
            $second[0].Chord | Should -Not -Be 'mutated'
        }
    }
}
