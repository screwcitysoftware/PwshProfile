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

    It 'ships both screwcity-simple and forestcity-simple theme files' {
        Test-Path (Join-Path $script:ThemeDir 'screwcity-simple.omp.json')  | Should -BeTrue
        Test-Path (Join-Path $script:ThemeDir 'forestcity-simple.omp.json') | Should -BeTrue
    }

    It 'both simple themes are valid JSON' {
        { Get-Content (Join-Path $script:ThemeDir 'screwcity-simple.omp.json')  -Raw | ConvertFrom-Json } | Should -Not -Throw
        { Get-Content (Join-Path $script:ThemeDir 'forestcity-simple.omp.json') -Raw | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'forestcity-simple is a palette-only twin of screwcity-simple (identical structure before the palette)' {
        $a = Get-Content (Join-Path $script:ThemeDir 'screwcity-simple.omp.json')  -Raw
        $b = Get-Content (Join-Path $script:ThemeDir 'forestcity-simple.omp.json') -Raw
        $a.Substring(0, $a.IndexOf('"palette"')) | Should -BeExactly $b.Substring(0, $b.IndexOf('"palette"'))
    }

    It 'both simple palettes define the same set of color keys (only the values differ)' {
        $a = (Get-Content (Join-Path $script:ThemeDir 'screwcity-simple.omp.json')  -Raw | ConvertFrom-Json).palette.PSObject.Properties.Name | Sort-Object
        $b = (Get-Content (Join-Path $script:ThemeDir 'forestcity-simple.omp.json') -Raw | ConvertFrom-Json).palette.PSObject.Properties.Name | Sort-Object
        $b | Should -Be $a
    }

    It 'screwcity-simple drops only the dev-tool segments (az/dotnet/node/docker)' {
        $theme = Get-Content (Join-Path $script:ThemeDir 'screwcity-simple.omp.json') -Raw | ConvertFrom-Json
        $types = $theme.blocks.segments.type
        $types | Should -Not -Contain 'az'
        $types | Should -Not -Contain 'dotnet'
        $types | Should -Not -Contain 'node'
        $types | Should -Not -Contain 'docker'
        $types | Should -Contain 'root'
        $types | Should -Contain 'os'
        $types | Should -Contain 'path'
        $types | Should -Contain 'git'
        $types | Should -Contain 'exit'
        $types | Should -Contain 'executiontime'
        $types | Should -Contain 'time'
        $types | Should -Contain 'text'
    }

    It 'screwcity-simple puts success/execution-time/clock on the main row, leaving the command row bare' {
        $theme = Get-Content (Join-Path $script:ThemeDir 'screwcity-simple.omp.json') -Raw | ConvertFrom-Json
        $theme.blocks.Count | Should -Be 3
        # Main row: left-aligned root/os/path/git, right-aligned exit/executiontime/time — neither newline nor rprompt.
        $theme.blocks[0].type      | Should -Be 'prompt'
        $theme.blocks[0].alignment | Should -Be 'left'
        $theme.blocks[0].PSObject.Properties.Name | Should -Not -Contain 'newline'
        $theme.blocks[1].type      | Should -Be 'prompt'
        $theme.blocks[1].alignment | Should -Be 'right'
        $theme.blocks[1].segments.type | Should -Be @('exit', 'executiontime', 'time')
        # Command row: just the arrow, on its own line.
        $theme.blocks[2].type      | Should -Be 'prompt'
        $theme.blocks[2].alignment | Should -Be 'left'
        $theme.blocks[2].newline   | Should -BeTrue
        $theme.blocks[2].segments.type | Should -Be @('text')
    }

    It 'screwcity-simple''s segments are otherwise identical to screwcity''s, minus the dev-tool block' {
        $full = Get-Content (Join-Path $script:ThemeDir 'screwcity.omp.json') -Raw | ConvertFrom-Json
        $simple = Get-Content (Join-Path $script:ThemeDir 'screwcity-simple.omp.json') -Raw | ConvertFrom-Json
        ($simple.blocks[0].segments | ConvertTo-Json -Depth 10) | Should -Be ($full.blocks[0].segments | ConvertTo-Json -Depth 10)
        ($simple.blocks[1].segments | ConvertTo-Json -Depth 10) | Should -Be ($full.blocks[2].segments | ConvertTo-Json -Depth 10)
        ($simple.blocks[2].segments | ConvertTo-Json -Depth 10) | Should -Be ($full.blocks[3].segments | ConvertTo-Json -Depth 10)
    }
}

Describe 'Bundled theme -Theme ArgumentCompleters tolerate duplicate loaded modules' {
    It 'still returns completions when Get-Module returns more than one module object' {
        $realModule = Get-Module $script:Module
        Mock Get-Module { @($realModule, $realModule) } -ParameterFilter { $Name -eq $script:Module }

        foreach ($cmd in 'Initialize-PwshProfile', 'Get-OhMyPoshTheme', 'Export-OhMyPoshTheme',
            'Install-WindowsTerminalScheme', 'Uninstall-WindowsTerminalScheme', 'Show-PwshProfileReadme') {
            $attr = (Get-Command $cmd).Parameters['Theme'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ArgumentCompleterAttribute] }
            $results = & $attr.ScriptBlock $cmd 'Theme' 'screw' $null $null
            $results.CompletionText | Should -Contain 'screwcity' -Because "$cmd should still complete with two module copies loaded"
            $results.CompletionText | Should -Contain 'screwcity-simple' -Because "$cmd should still complete with two module copies loaded"
        }
    }
}

Describe 'Get-BundledThemeName' {
    It 'discovers the bundled themes by name (suffix stripped)' {
        InModuleScope $script:Module {
            $names = @(Get-BundledThemeName)
            $names | Should -Contain 'screwcity'
            $names | Should -Contain 'forestcity'
            $names | Should -Contain 'screwcity-simple'
            $names | Should -Contain 'forestcity-simple'
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
            $b.MarkdownHeaderColor | Should -Be '[1;38;2;201;170;255m'
            $b.MarkdownCodeColor   | Should -Be '[38;2;95;215;255m'
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
            $b.MarkdownHeaderColor | Should -Be '[1;38;2;143;206;114m'
            $b.MarkdownCodeColor   | Should -Be '[38;2;102;217;197m'
        }
    }

    It 'falls back to the screwcity branding for an unknown/custom theme' {
        InModuleScope $script:Module {
            (Get-BundledThemeBranding -Name 'something-custom').DisplayName | Should -Be 'Screw City'
        }
    }

    It 'screwcity-simple shares screwcity''s branding except for DisplayName' {
        InModuleScope $script:Module {
            $parent = Get-BundledThemeBranding -Name screwcity
            $simple = Get-BundledThemeBranding -Name screwcity-simple
            $simple.DisplayName | Should -Be 'Screw City (Simple)'
            $simple.BannerColor | Should -Be $parent.BannerColor
            $simple.StepIcon    | Should -Be $parent.StepIcon
            $simple.BatTheme    | Should -Be $parent.BatTheme
            $simple.LsColors    | Should -Be $parent.LsColors
            $simple.FzfColors   | Should -Be $parent.FzfColors
            $simple.MarkdownHeaderColor | Should -Be $parent.MarkdownHeaderColor
            $simple.MarkdownCodeColor   | Should -Be $parent.MarkdownCodeColor
            # Same Windows Terminal scheme identity (name included) as the parent theme.
            $simple.TerminalScheme.name | Should -Be $parent.TerminalScheme.name
            ($simple.TerminalScheme | ConvertTo-Json) | Should -Be ($parent.TerminalScheme | ConvertTo-Json)
        }
    }

    It 'forestcity-simple shares forestcity''s branding except for DisplayName' {
        InModuleScope $script:Module {
            $parent = Get-BundledThemeBranding -Name forestcity
            $simple = Get-BundledThemeBranding -Name forestcity-simple
            $simple.DisplayName | Should -Be 'Forest City (Simple)'
            $simple.BannerColor | Should -Be $parent.BannerColor
            $simple.StepIcon    | Should -Be $parent.StepIcon
            $simple.BatTheme    | Should -Be $parent.BatTheme
            $simple.LsColors    | Should -Be $parent.LsColors
            $simple.FzfColors   | Should -Be $parent.FzfColors
            $simple.MarkdownHeaderColor | Should -Be $parent.MarkdownHeaderColor
            $simple.MarkdownCodeColor   | Should -Be $parent.MarkdownCodeColor
            $simple.TerminalScheme.name | Should -Be $parent.TerminalScheme.name
            ($simple.TerminalScheme | ConvertTo-Json) | Should -Be ($parent.TerminalScheme | ConvertTo-Json)
        }
    }
}
