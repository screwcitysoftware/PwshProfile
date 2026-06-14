#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'

    # A real, existing file so the -CustomTheme ValidateScript accepts it.
    $script:ThemePath = Join-Path ([System.IO.Path]::GetTempPath()) 'sc-test-theme.omp.json'
    Set-Content -Path $script:ThemePath -Value '{}' -Force

    # A real, existing file so the -BannerFontPath ValidateScript accepts it.
    $script:FontPath = Join-Path ([System.IO.Path]::GetTempPath()) 'sc-test-font.flf'
    Set-Content -Path $script:FontPath -Value 'flf2a$' -Force
}

AfterAll {
    Remove-Item -Path $script:ThemePath -ErrorAction SilentlyContinue
    Remove-Item -Path $script:FontPath -ErrorAction SilentlyContinue
}

Describe 'Initialize-PwshProfile' {
    BeforeEach {
        # Run each step body inline (no spinner) and stub every leaf, so the orchestration is
        # exercised without rendering or triggering any winget auto-install.
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Mock -ModuleName $script:Module Write-Figlet { }
        Mock -ModuleName $script:Module Write-SpectreHost { }
        Mock -ModuleName $script:Module Initialize-PSReadline { }
        Mock -ModuleName $script:Module Import-ModuleSafe { }
        Mock -ModuleName $script:Module Enable-OhMyPosh { }
        Mock -ModuleName $script:Module Enable-Zoxide { }
        Mock -ModuleName $script:Module Enable-FastNodeManager { }
        Mock -ModuleName $script:Module Enable-Xh { }
        Mock -ModuleName $script:Module Enable-WingetCompletion { }
        Mock -ModuleName $script:Module Enable-AzCompletion { }
        Mock -ModuleName $script:Module Enable-TailscaleCompletion { }
        Mock -ModuleName $script:Module Enable-DockerCompletion { }
        Mock -ModuleName $script:Module Enable-1PasswordCompletion { }
    }

    Context 'defaults reproduce the full startup' {
        It 'shows the banner and enables every tool with default arguments' {
            Initialize-PwshProfile
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-OhMyPosh -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-Zoxide -Times 1 -Exactly -ParameterFilter { $Command -eq 'cd' }
            Should -Invoke -ModuleName $script:Module Enable-FastNodeManager -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-Xh -Times 1 -Exactly
            # Completions register by default (as the final sub-step of Tools).
            Should -Invoke -ModuleName $script:Module Enable-WingetCompletion -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-AzCompletion -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-TailscaleCompletion -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-DockerCompletion -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-1PasswordCompletion -Times 1 -Exactly
        }
    }

    Context 'pass-through parameters' {
        It 'forwards -CustomTheme to Enable-OhMyPosh as -Configuration' {
            Initialize-PwshProfile -CustomTheme $script:ThemePath
            Should -Invoke -ModuleName $script:Module Enable-OhMyPosh -Times 1 -Exactly `
                -ParameterFilter { $Configuration -eq $ThemePath }
        }

        It 'forwards -ZoxideCommand to Enable-Zoxide as -Command' {
            Initialize-PwshProfile -ZoxideCommand 'z'
            Should -Invoke -ModuleName $script:Module Enable-Zoxide -Times 1 -Exactly `
                -ParameterFilter { $Command -eq 'z' }
        }

        It 'forwards -StepIcon to the top-level Invoke-Step calls' {
            Initialize-PwshProfile -StepIcon '🚀'
            Should -Invoke -ModuleName $script:Module Invoke-Step -Times 1 -Exactly `
                -ParameterFilter { $Description -eq 'Prompt' -and $Icon -eq '🚀' }
        }

        It 'forwards -BannerFont to Write-Figlet as -Font' {
            Initialize-PwshProfile -BannerFont ANSIShadow
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 1 -Exactly `
                -ParameterFilter { $Font -eq 'ANSIShadow' }
        }

        It 'forwards -BannerFontPath to Write-Figlet as -FontPath' {
            Initialize-PwshProfile -BannerFontPath $script:FontPath
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 1 -Exactly `
                -ParameterFilter { $FontPath -eq $script:FontPath }
        }

        It 'passes neither -Font nor -FontPath when no banner font is requested' {
            Initialize-PwshProfile
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 1 -Exactly `
                -ParameterFilter { -not $PSBoundParameters.ContainsKey('Font') -and -not $PSBoundParameters.ContainsKey('FontPath') }
        }
    }

    Context '-Skip opts out of individual tools' {
        It 'skips a single tool but keeps its siblings' {
            Initialize-PwshProfile -Skip Zoxide
            Should -Invoke -ModuleName $script:Module Enable-Zoxide -Times 0 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-OhMyPosh -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-FastNodeManager -Times 1 -Exactly
        }

        It 'skips the banner' {
            Initialize-PwshProfile -Skip Banner
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 0 -Exactly
        }

        It 'renders no banner when the banner text is empty' {
            Initialize-PwshProfile -BannerText ''
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 0 -Exactly
        }
    }

    Context '-Skip Completions drops the shell completions' {
        It 'skips the completion registrations under Tools' {
            Initialize-PwshProfile -Skip Completions
            Should -Invoke -ModuleName $script:Module Enable-WingetCompletion -Times 0 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-AzCompletion -Times 0 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-TailscaleCompletion -Times 0 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-DockerCompletion -Times 0 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-1PasswordCompletion -Times 0 -Exactly
        }

        It 'leaves xh running when Completions is skipped, since both live under Tools' {
            Initialize-PwshProfile -Skip Completions
            Should -Invoke -ModuleName $script:Module Enable-Xh -Times 1 -Exactly
        }
    }

    Context '-SkipSection opts out of whole sections' {
        It 'skips the whole Tools section, including the completions nested under it' {
            Initialize-PwshProfile -SkipSection Tools
            Should -Invoke -ModuleName $script:Module Enable-Zoxide -Times 0 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-FastNodeManager -Times 0 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-Xh -Times 0 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-WingetCompletion -Times 0 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-AzCompletion -Times 0 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-TailscaleCompletion -Times 0 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-DockerCompletion -Times 0 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-1PasswordCompletion -Times 0 -Exactly
        }
    }

    Context 'oh-my-posh is unskippable' {
        It 'still enables oh-my-posh when every skippable section is skipped' {
            Initialize-PwshProfile -SkipSection Shell, Tools
            Should -Invoke -ModuleName $script:Module Enable-OhMyPosh -Times 1 -Exactly
        }

        It 'keeps oh-my-posh but drops the cosmetic extras (with a warning) on -SkipSection Prompt' {
            Initialize-PwshProfile -SkipSection Prompt -WarningVariable warnings -WarningAction SilentlyContinue
            Should -Invoke -ModuleName $script:Module Enable-OhMyPosh -Times 1 -Exactly
            # Terminal-Icons and posh-git are the only Import-ModuleSafe calls under Prompt; both dropped.
            Should -Invoke -ModuleName $script:Module Import-ModuleSafe -Times 0 -Exactly `
                -ParameterFilter { $Name -in 'Terminal-Icons', 'posh-git' }
            $warnings | Should -Not -BeNullOrEmpty
        }
    }

    Context 'theme selection and branding' {
        It 'uses the bundled screwcity theme and its branding by default' {
            Initialize-PwshProfile
            Should -Invoke -ModuleName $script:Module Enable-OhMyPosh -Times 1 -Exactly `
                -ParameterFilter { $Configuration -like '*screwcity.omp.json' }
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 1 -Exactly `
                -ParameterFilter { $Text -eq $env:COMPUTERNAME -and $Color -eq '#c9aaff' }
            Should -Invoke -ModuleName $script:Module Invoke-Step -Times 1 -Exactly `
                -ParameterFilter { $Description -eq 'Prompt' -and $Icon -eq ':nut_and_bolt:' }
        }

        It 'resolves -Theme forestcity to its bundled file and Forest City branding' {
            Initialize-PwshProfile -Theme forestcity
            Should -Invoke -ModuleName $script:Module Enable-OhMyPosh -Times 1 -Exactly `
                -ParameterFilter { $Configuration -like '*forestcity.omp.json' }
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 1 -Exactly `
                -ParameterFilter { $Text -eq $env:COMPUTERNAME -and $Color -eq '#8fce72' }
            Should -Invoke -ModuleName $script:Module Invoke-Step -Times 1 -Exactly `
                -ParameterFilter { $Description -eq 'Prompt' -and $Icon -eq ':deciduous_tree:' }
        }

        It 'lets an explicit banner value override the theme branding' {
            Initialize-PwshProfile -Theme forestcity -BannerColor Red -BannerText 'CUSTOM'
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 1 -Exactly `
                -ParameterFilter { $Text -eq 'CUSTOM' -and $Color -eq 'Red' }
        }

        It 'keeps the neutral screwcity branding for a -CustomTheme' {
            Initialize-PwshProfile -CustomTheme $script:ThemePath
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 1 -Exactly `
                -ParameterFilter { $Text -eq $env:COMPUTERNAME -and $Color -eq '#c9aaff' }
        }
    }

    Context 'validation' {
        It 'rejects OhMyPosh as a Skip token, keeping it table stakes' {
            { Initialize-PwshProfile -Skip OhMyPosh } | Should -Throw
        }

        It 'rejects a non-existent -CustomTheme path' {
            { Initialize-PwshProfile -CustomTheme 'X:\does\not\exist.omp.json' } | Should -Throw
        }

        It 'rejects an unknown -Theme name' {
            { Initialize-PwshProfile -Theme nope } | Should -Throw
        }

        It 'rejects -Theme and -CustomTheme together (mutually exclusive sets)' {
            { Initialize-PwshProfile -Theme screwcity -CustomTheme $script:ThemePath } | Should -Throw
        }

        It 'rejects an unknown -BannerFont name' {
            { Initialize-PwshProfile -BannerFont Nope } | Should -Throw
        }

        It 'rejects a non-existent -BannerFontPath' {
            { Initialize-PwshProfile -BannerFontPath 'X:\does\not\exist.flf' } | Should -Throw
        }
    }
}
