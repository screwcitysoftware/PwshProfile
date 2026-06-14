#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
    # Source of truth: the bundled .flf base names on disk.
    $script:Expected = (Get-ChildItem -Path (Join-Path $PSScriptRoot '..' 'Assets' 'Fonts') -Filter *.flf).BaseName | Sort-Object
}

Describe 'Show-FigletFont' {
    BeforeEach {
        # Mock at the Write-Figlet boundary so we can assert what gets rendered without drawing,
        # and so we sidestep the [Spectre.Console.Color] transform the Spectre mock can't replicate.
        Mock -ModuleName $script:Module Write-Figlet { }
        Mock -ModuleName $script:Module Write-SpectreHost { }
    }

    Context 'listing (default)' {
        It 'lists every bundled font name and renders nothing' {
            $names = Show-FigletFont
            $names | Sort-Object | Should -Be $script:Expected
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 0 -Exactly
        }

        It 'lists only the requested subset' {
            Show-FigletFont -Font Small, Slant | Sort-Object | Should -Be ('Slant', 'Small')
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 0 -Exactly
        }
    }

    Context '-Preview' {
        It 'previews every bundled font' {
            Show-FigletFont -Preview
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times $script:Expected.Count -Exactly
        }

        It 'previews only the requested subset' {
            Show-FigletFont -Font Small, Slant -Preview
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 2 -Exactly
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 1 -Exactly -ParameterFilter { $FontPath -like '*Small.flf' }
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 1 -Exactly -ParameterFilter { $FontPath -like '*Slant.flf' }
        }

        It 'defaults the sample text to each font name' {
            Show-FigletFont -Font ANSIShadow -Preview
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 1 -Exactly `
                -ParameterFilter { $Text -eq 'ANSIShadow' }
        }

        It 'forwards -Text to every sample' {
            Show-FigletFont -Font Small, Standard -Preview -Text 'Hi'
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 2 -Exactly `
                -ParameterFilter { $Text -eq 'Hi' }
        }
    }

    Context 'validation' {
        It 'rejects an unknown -Font name' {
            { Show-FigletFont -Font Nope } | Should -Throw
        }
    }
}

Describe 'Show-FigletFont / Write-Figlet font list' {
    It 'every listed font name is accepted by Write-Figlet -Font' {
        Mock -ModuleName $script:Module Write-SpectreFigletText -RemoveParameterType 'Color' { }
        foreach ($name in (Show-FigletFont)) {
            { Write-Figlet 'x' -Font $name } | Should -Not -Throw -Because "$name should be a valid -Font value"
        }
    }
}

Describe 'Show-FigletFont rendering (unmocked smoke test)' {
    It 'previews without throwing' {
        { Show-FigletFont -Font ANSIShadow -Preview } | Should -Not -Throw
    }
}
