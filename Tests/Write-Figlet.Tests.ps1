#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'

    # A real, existing .flf so the -FontPath ValidateScript accepts it.
    $script:CustomFont = Join-Path ([System.IO.Path]::GetTempPath()) 'sc-test-custom.flf'
    Set-Content -Path $script:CustomFont -Value 'flf2a$' -Force
}

AfterAll {
    Remove-Item -Path $script:CustomFont -ErrorAction SilentlyContinue
}

Describe 'Write-Figlet' {
    BeforeEach {
        # Intercept the Spectre renderer so nothing is drawn and we can inspect arguments.
        # -RemoveParameterType Color: the real -Color is [Spectre.Console.Color] and relies on a
        # custom string->Color transformation attribute that the mock doesn't replicate, so a
        # string like 'Blue' won't bind to the mock without dropping the type.
        Mock -ModuleName $script:Module Write-SpectreFigletText -RemoveParameterType 'Color' { }
    }

    Context 'font selection' {
        It 'defaults to the ANSIShadow bundled font' {
            Write-Figlet 'Hi'
            Should -Invoke -ModuleName $script:Module Write-SpectreFigletText -Times 1 -Exactly `
                -ParameterFilter { $FigletFontPath -like '*ANSIShadow.flf' -and (Test-Path -Path $FigletFontPath) }
        }

        It 'defaults the color to the theme purple #c9aaff' {
            Write-Figlet 'Hi'
            Should -Invoke -ModuleName $script:Module Write-SpectreFigletText -Times 1 -Exactly `
                -ParameterFilter { $Color -eq '#c9aaff' }
        }

        It 'resolves -Font to the bundled .flf and passes it as -FigletFontPath' {
            Write-Figlet 'Hi' -Font ANSIShadow
            Should -Invoke -ModuleName $script:Module Write-SpectreFigletText -Times 1 -Exactly `
                -ParameterFilter { $FigletFontPath -like '*ANSIShadow.flf' -and (Test-Path -Path $FigletFontPath) }
        }

        It 'passes -FontPath through verbatim as -FigletFontPath' {
            Write-Figlet 'Hi' -FontPath $script:CustomFont
            Should -Invoke -ModuleName $script:Module Write-SpectreFigletText -Times 1 -Exactly `
                -ParameterFilter { $FigletFontPath -eq $script:CustomFont }
        }

        It 'forwards Color and Alignment' {
            Write-Figlet 'Hi' -Color Green -Alignment Center
            Should -Invoke -ModuleName $script:Module Write-SpectreFigletText -Times 1 -Exactly `
                -ParameterFilter { $Color -eq 'Green' -and $Alignment -eq 'Center' }
        }
    }

    Context 'validation' {
        It 'requires -Text' {
            # Probe the requirement with an explicit empty string rather than omitting -Text: an
            # omitted mandatory parameter makes an *interactive* host prompt for it (hanging the run),
            # whereas an empty string is rejected by the mandatory binding check in any host.
            { Write-Figlet -Text '' -Color Blue } | Should -Throw
        }

        It 'rejects an unknown -Font name' {
            { Write-Figlet 'Hi' -Font Nope } | Should -Throw
        }

        It 'rejects a non-existent -FontPath' {
            { Write-Figlet 'Hi' -FontPath 'X:\does\not\exist.flf' } | Should -Throw
        }

        It 'rejects -Font and -FontPath together (mutually exclusive parameter sets)' {
            { Write-Figlet 'Hi' -Font Small -FontPath $script:CustomFont } | Should -Throw
        }
    }

    Context 'failure tolerance' {
        It 'warns and falls back to the default font when a bundled font file is missing' {
            # Keep -Font validation passing (it enumerates via Get-BundledFontName) but make the
            # per-font path resolution return a non-existent file to exercise the warn + fallback.
            Mock -ModuleName $script:Module Get-BundledFontName { @('Small') }
            Mock -ModuleName $script:Module Get-BundledFontPath { 'X:\missing\Small.flf' } -ParameterFilter { $Name }
            Write-Figlet 'Hi' -Font Small -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings | Should -Not -BeNullOrEmpty
            Should -Invoke -ModuleName $script:Module Write-SpectreFigletText -Times 1 -Exactly `
                -ParameterFilter { -not $PSBoundParameters.ContainsKey('FigletFontPath') }
        }
    }
}
