#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
    $script:ThemeDir = Join-Path $PSScriptRoot '..' 'Assets' 'Themes'
}

Describe 'Bundled themes' {
    It 'ships both screwcity and forestcity theme files' {
        Test-Path (Join-Path $script:ThemeDir 'screwcity.omp.json')  | Should -BeTrue
        Test-Path (Join-Path $script:ThemeDir 'forestcity.omp.json') | Should -BeTrue
    }

    It 'both themes are valid JSON' {
        { Get-Content (Join-Path $script:ThemeDir 'screwcity.omp.json')  -Raw | ConvertFrom-Json } | Should -Not -Throw
        { Get-Content (Join-Path $script:ThemeDir 'forestcity.omp.json') -Raw | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'forestcity is a palette-only twin of screwcity (identical structure before the palette)' {
        $a = Get-Content (Join-Path $script:ThemeDir 'screwcity.omp.json')  -Raw
        $b = Get-Content (Join-Path $script:ThemeDir 'forestcity.omp.json') -Raw
        $a.Substring(0, $a.IndexOf('"palette"')) | Should -BeExactly $b.Substring(0, $b.IndexOf('"palette"'))
    }

    It 'both palettes define the same set of color keys (only the values differ)' {
        $a = (Get-Content (Join-Path $script:ThemeDir 'screwcity.omp.json')  -Raw | ConvertFrom-Json).palette.PSObject.Properties.Name | Sort-Object
        $b = (Get-Content (Join-Path $script:ThemeDir 'forestcity.omp.json') -Raw | ConvertFrom-Json).palette.PSObject.Properties.Name | Sort-Object
        $b | Should -Be $a
    }
}

Describe 'Get-BundledThemeName' {
    It 'discovers the bundled themes by name (suffix stripped)' {
        InModuleScope $script:Module {
            $names = @(Get-BundledThemeName)
            $names | Should -Contain 'screwcity'
            $names | Should -Contain 'forestcity'
            # Names are stripped of the .omp.json suffix.
            $names | Should -Not -Contain 'screwcity.omp'
        }
    }
}

Describe 'Get-BundledThemePath' {
    It 'defaults to the screwcity theme' {
        InModuleScope $script:Module {
            Get-BundledThemePath | Should -BeLike '*screwcity.omp.json'
        }
    }

    It 'resolves a named theme' {
        InModuleScope $script:Module {
            Get-BundledThemePath -Name forestcity | Should -BeLike '*forestcity.omp.json'
        }
    }
}

Describe 'Get-BundledThemeBranding' {
    It 'returns the Screw City branding for screwcity' {
        InModuleScope $script:Module {
            $b = Get-BundledThemeBranding -Name screwcity
            $b.DisplayName | Should -Be 'Screw City'
            $b.BannerColor | Should -Be '#4c81c8'
            $b.StepIcon    | Should -Be ':nut_and_bolt:'
            $b.BatTheme    | Should -Be 'Dracula'
            # fd (LS_COLORS) and fzf color specs blend with the purple/cyan palette.
            $b.LsColors    | Should -Match 'di=1;38;2;201;170;255'
            $b.FzfColors   | Should -Match 'pointer:#c9aaff'
        }
    }

    It 'returns the Forest City branding for forestcity' {
        InModuleScope $script:Module {
            $b = Get-BundledThemeBranding -Name forestcity
            $b.DisplayName | Should -Be 'Forest City'
            $b.BannerColor | Should -Be '#8fce72'
            $b.StepIcon    | Should -Be ':deciduous_tree:'
            $b.BatTheme    | Should -Be 'gruvbox-dark'
            # fd (LS_COLORS) and fzf color specs blend with the green/gold palette.
            $b.LsColors    | Should -Match 'di=1;38;2;143;206;114'
            $b.FzfColors   | Should -Match 'pointer:#8fce72'
        }
    }

    It 'falls back to the screwcity branding for an unknown/custom theme' {
        InModuleScope $script:Module {
            (Get-BundledThemeBranding -Name 'something-custom').DisplayName | Should -Be 'Screw City'
        }
    }
}
