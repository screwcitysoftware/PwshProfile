#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
}

Describe 'Show-NerdFontSetup' {
    BeforeEach {
        # Capture the panel text instead of rendering it. -RemoveParameterType Color: the mock
        # doesn't replicate the string->Color transform.
        $script:Panel = $null
        Mock -ModuleName $script:Module Format-SpectrePanel -RemoveParameterType 'Color' {
            $script:Panel = "$Data"
        }
        Mock -ModuleName $script:Module Write-SpectreHost { }
    }

    It 'maps Meslo to its terminal family name' {
        Show-NerdFontSetup -Font Meslo
        $script:Panel | Should -Match 'MesloLGM Nerd Font'
    }

    It 'maps CascadiaCode to CaskaydiaCove Nerd Font' {
        Show-NerdFontSetup -Font CascadiaCode
        $script:Panel | Should -Match 'CaskaydiaCove Nerd Font'
    }

    It 'shows both recommended families when no font is given' {
        Show-NerdFontSetup
        $script:Panel | Should -Match 'MesloLGM Nerd Font'
        $script:Panel | Should -Match 'CaskaydiaCove Nerd Font'
    }

    It 'always names Windows Terminal and VS Code' {
        Show-NerdFontSetup -Font Meslo
        $script:Panel | Should -Match 'Windows Terminal'
        $script:Panel | Should -Match 'VS Code'
    }

    It 'renders without throwing for an unrecognized font and adds the generic note' {
        { Show-NerdFontSetup -Font 'TotallyMadeUpFont' } | Should -Not -Throw
        # Match the line unique to the $generic fallback, not the ubiquitous 'Nerd Font' substring.
        $script:Panel | Should -Match 'For any other Nerd Font'
    }

    It 'renders exactly one panel' {
        Show-NerdFontSetup -Font Meslo, CascadiaCode
        Should -Invoke -ModuleName $script:Module Format-SpectrePanel -Times 1 -Exactly
    }
}
