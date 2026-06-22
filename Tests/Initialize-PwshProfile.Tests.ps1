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
        Mock -ModuleName $script:Module Enable-Fzf { }
        Mock -ModuleName $script:Module Enable-FastNodeManager { }
        Mock -ModuleName $script:Module Enable-Xh { }
        Mock -ModuleName $script:Module Enable-Jq { }
        Mock -ModuleName $script:Module Enable-Bat { }
        Mock -ModuleName $script:Module Enable-Fd { }
        Mock -ModuleName $script:Module Enable-Less { }
        Mock -ModuleName $script:Module Enable-WingetCompletion { }
        Mock -ModuleName $script:Module Enable-AzureCliCompletion { }
        Mock -ModuleName $script:Module Enable-TailscaleCompletion { }
        Mock -ModuleName $script:Module Enable-DockerCompletion { }
        Mock -ModuleName $script:Module Enable-1PasswordCompletion { }
        Mock -ModuleName $script:Module Enable-GithubCliCompletion { }
        # Deterministic bare-call resolution: a bare Initialize-PwshProfile enables nothing unless a
        # test overrides this mock to return $true.
        Mock -ModuleName $script:Module Confirm-PwshProfileEnableAll { $false }
    }

    Context '-EnableAll runs the full startup' {
        It 'shows the banner and enables every tool with default arguments' {
            Initialize-PwshProfile -EnableAll
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-OhMyPosh -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-Zoxide -Times 1 -Exactly -ParameterFilter { $Command -eq 'cd' }
            # fzf enables with the screwcity blend, full style, bat preview, PSFzf Ctrl+T/Ctrl+R
            # bindings, fd traversal, and git chords.
            Should -Invoke -ModuleName $script:Module Enable-Fzf -Times 1 -Exactly `
                -ParameterFilter { $Colors -like '*pointer:#c9aaff*' -and $Style -eq 'full' -and $Height -eq '~100%' -and $PreviewCommand -like 'bat *' -and `
                    $ProviderChord -eq 'Ctrl+t' -and $HistoryChord -eq 'Ctrl+r' -and $TabExpansionChord -eq 'Ctrl+Spacebar' -and $UseFd -and $GitKeyBindings }
            Should -Invoke -ModuleName $script:Module Enable-FastNodeManager -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-Xh -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-Jq -Times 1 -Exactly
            # bat enables with the screwcity blend theme and cat left intact.
            Should -Invoke -ModuleName $script:Module Enable-Bat -Times 1 -Exactly `
                -ParameterFilter { $Theme -eq 'Dracula' -and $Style -eq 'numbers,changes,header' -and -not $ReplaceCat }
            # fd enables with the screwcity LS_COLORS blend and fzf integration on.
            Should -Invoke -ModuleName $script:Module Enable-Fd -Times 1 -Exactly `
                -ParameterFilter { $LsColors -like '*di=1;38;2;201;170;255*' -and $IntegrateFzf }
            # less enables with the pager-override left off.
            Should -Invoke -ModuleName $script:Module Enable-Less -Times 1 -Exactly `
                -ParameterFilter { -not $ReplaceMore }
            # Completions register (under Core).
            Should -Invoke -ModuleName $script:Module Enable-WingetCompletion -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-AzureCliCompletion -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-TailscaleCompletion -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-DockerCompletion -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-1PasswordCompletion -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-GithubCliCompletion -Times 1 -Exactly
        }
    }

    Context 'pass-through parameters' {
        It 'forwards -CustomTheme to Enable-OhMyPosh as -Configuration' {
            Initialize-PwshProfile -CustomTheme $script:ThemePath -EnableAll
            Should -Invoke -ModuleName $script:Module Enable-OhMyPosh -Times 1 -Exactly `
                -ParameterFilter { $Configuration -eq $ThemePath }
        }

        It 'forwards -ZoxideCommand to Enable-Zoxide as -Command' {
            Initialize-PwshProfile -EnableAll -ZoxideCommand 'z'
            Should -Invoke -ModuleName $script:Module Enable-Zoxide -Times 1 -Exactly `
                -ParameterFilter { $Command -eq 'z' }
        }

        It 'forwards -ReplaceCat and -BatStyle to Enable-Bat' {
            Initialize-PwshProfile -EnableAll -ReplaceCat -BatStyle 'plain'
            Should -Invoke -ModuleName $script:Module Enable-Bat -Times 1 -Exactly `
                -ParameterFilter { $ReplaceCat -and $Style -eq 'plain' }
        }

        It 'forwards -ReplaceMore to Enable-Less' {
            Initialize-PwshProfile -EnableAll -ReplaceMore
            Should -Invoke -ModuleName $script:Module Enable-Less -Times 1 -Exactly `
                -ParameterFilter { $ReplaceMore }
        }

        It 'forwards an explicit -BatTheme, overriding the theme blend' {
            Initialize-PwshProfile -EnableAll -BatTheme 'Nord'
            Should -Invoke -ModuleName $script:Module Enable-Bat -Times 1 -Exactly `
                -ParameterFilter { $Theme -eq 'Nord' }
        }

        It 'blends bat with the forestcity theme by default' {
            Initialize-PwshProfile -Theme forestcity -EnableAll
            Should -Invoke -ModuleName $script:Module Enable-Bat -Times 1 -Exactly `
                -ParameterFilter { $Theme -eq 'gruvbox-dark' }
        }

        It 'blends fd and fzf with the forestcity palette by default' {
            Initialize-PwshProfile -Theme forestcity -EnableAll
            Should -Invoke -ModuleName $script:Module Enable-Fd -Times 1 -Exactly `
                -ParameterFilter { $LsColors -like '*di=1;38;2;143;206;114*' }
            Should -Invoke -ModuleName $script:Module Enable-Fzf -Times 1 -Exactly `
                -ParameterFilter { $Colors -like '*pointer:#8fce72*' }
        }

        It 'forwards explicit -FdColors and -FzfColors, overriding the theme blend' {
            Initialize-PwshProfile -EnableAll -FdColors 'di=0' -FzfColors 'pointer:#ff0000'
            Should -Invoke -ModuleName $script:Module Enable-Fd -Times 1 -Exactly `
                -ParameterFilter { $LsColors -eq 'di=0' }
            Should -Invoke -ModuleName $script:Module Enable-Fzf -Times 1 -Exactly `
                -ParameterFilter { $Colors -eq 'pointer:#ff0000' }
        }

        It 'forwards -StepIcon to the top-level Invoke-Step calls' {
            Initialize-PwshProfile -EnableAll -StepIcon '🚀'
            Should -Invoke -ModuleName $script:Module Invoke-Step -Times 1 -Exactly `
                -ParameterFilter { $Description -eq 'Core' -and $Icon -eq '🚀' }
        }

        It 'forwards -BannerFont to Write-Figlet as -Font' {
            Initialize-PwshProfile -EnableAll -BannerFont ANSIShadow
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 1 -Exactly `
                -ParameterFilter { $Font -eq 'ANSIShadow' }
        }

        It 'forwards -BannerFontPath to Write-Figlet as -FontPath' {
            Initialize-PwshProfile -EnableAll -BannerFontPath $script:FontPath
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 1 -Exactly `
                -ParameterFilter { $FontPath -eq $script:FontPath }
        }

        It 'passes neither -Font nor -FontPath when no banner font is requested' {
            Initialize-PwshProfile -EnableAll
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 1 -Exactly `
                -ParameterFilter { -not $PSBoundParameters.ContainsKey('Font') -and -not $PSBoundParameters.ContainsKey('FontPath') }
        }
    }

    Context '-Enable opts in to individual tools' {
        It 'enables only the listed tool, leaving siblings off (oh-my-posh always runs)' {
            Initialize-PwshProfile -Enable Zoxide
            Should -Invoke -ModuleName $script:Module Enable-Zoxide -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-OhMyPosh -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-FastNodeManager -Times 0 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-Bat -Times 0 -Exactly
        }

        It 'honors Jq via -Enable' {
            Initialize-PwshProfile -Enable Jq
            Should -Invoke -ModuleName $script:Module Enable-Jq -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-Xh -Times 0 -Exactly
        }

        It 'wires fzf to use fd and a bat preview when fzf, fd, and bat are all enabled' {
            Initialize-PwshProfile -Enable Fzf, Fd, Bat
            Should -Invoke -ModuleName $script:Module Enable-Fzf -Times 1 -Exactly `
                -ParameterFilter { $UseFd -and $PreviewCommand -like 'bat *' }
            Should -Invoke -ModuleName $script:Module Enable-Fd -Times 1 -Exactly `
                -ParameterFilter { $IntegrateFzf }
        }

        It 'drops fzf''s -UseFd and bat preview when only fzf is enabled' {
            Initialize-PwshProfile -Enable Fzf
            Should -Invoke -ModuleName $script:Module Enable-Fzf -Times 1 -Exactly `
                -ParameterFilter { -not $UseFd -and [string]::IsNullOrEmpty($PreviewCommand) -and $Style -eq 'full' }
        }

        It 'drops fd''s fzf integration when only fd is enabled' {
            Initialize-PwshProfile -Enable Fd
            Should -Invoke -ModuleName $script:Module Enable-Fd -Times 1 -Exactly `
                -ParameterFilter { -not $IntegrateFzf }
        }

        It 'registers completions when -Enable Completions, without other tools' {
            Initialize-PwshProfile -Enable Completions
            Should -Invoke -ModuleName $script:Module Enable-WingetCompletion -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-GithubCliCompletion -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-Xh -Times 0 -Exactly
        }

        It '-Enable @() enables nothing but still runs oh-my-posh' {
            Initialize-PwshProfile -Enable @()
            Should -Invoke -ModuleName $script:Module Enable-OhMyPosh -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-Zoxide -Times 0 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-WingetCompletion -Times 0 -Exactly
        }

        It 'renders Core but not WinGet when only a Core token is enabled' {
            Initialize-PwshProfile -Enable PSReadLine
            Should -Invoke -ModuleName $script:Module Invoke-Step -Times 1 -Exactly `
                -ParameterFilter { $Description -eq 'Core' }
            Should -Invoke -ModuleName $script:Module Invoke-Step -Times 0 -Exactly `
                -ParameterFilter { $Description -eq 'WinGet' }
        }

        It 'renders the WinGet section when a winget tool is enabled' {
            Initialize-PwshProfile -Enable Jq
            Should -Invoke -ModuleName $script:Module Invoke-Step -Times 1 -Exactly `
                -ParameterFilter { $Description -eq 'WinGet' }
        }
    }

    Context '-EnableAll and -Enable precedence' {
        It 'lets -Enable win over -EnableAll, with a warning' {
            Initialize-PwshProfile -Enable Zoxide -EnableAll -WarningVariable warnings -WarningAction SilentlyContinue
            Should -Invoke -ModuleName $script:Module Enable-Zoxide -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-Fzf -Times 0 -Exactly
            $warnings | Should -Not -BeNullOrEmpty
        }
    }

    Context 'bare call resolution' {
        It 'enables nothing when the confirm declines (e.g. non-interactive)' {
            Initialize-PwshProfile
            Should -Invoke -ModuleName $script:Module Enable-Zoxide -Times 0 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-OhMyPosh -Times 1 -Exactly
        }

        It 'enables everything when the confirm accepts' {
            Mock -ModuleName $script:Module Confirm-PwshProfileEnableAll { $true }
            Initialize-PwshProfile
            Should -Invoke -ModuleName $script:Module Enable-Zoxide -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-Bat -Times 1 -Exactly
        }
    }

    Context 'parameter/tool coupling' {
        It 'warns and ignores a tool param whose tool is not enabled, without throwing' {
            { Initialize-PwshProfile -Enable Zoxide -ReplaceCat -WarningVariable warnings -WarningAction SilentlyContinue } |
                Should -Not -Throw
            Should -Invoke -ModuleName $script:Module Enable-Bat -Times 0 -Exactly
        }

        It 'stays quiet when the tool param''s tool is enabled' {
            Initialize-PwshProfile -Enable Bat -ReplaceCat -WarningVariable warnings -WarningAction SilentlyContinue
            $couplingWarnings = @($warnings | Where-Object { "$_" -like '*ReplaceCat*' })
            $couplingWarnings | Should -BeNullOrEmpty
            Should -Invoke -ModuleName $script:Module Enable-Bat -Times 1 -Exactly -ParameterFilter { $ReplaceCat }
        }
    }

    Context 'banner control' {
        It 'renders no banner under -NoBanner' {
            Initialize-PwshProfile -EnableAll -NoBanner
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 0 -Exactly
        }

        It 'warns and ignores banner params passed with -NoBanner' {
            Initialize-PwshProfile -EnableAll -NoBanner -BannerColor Green -WarningVariable warnings -WarningAction SilentlyContinue
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 0 -Exactly
            $warnings | Should -Not -BeNullOrEmpty
        }

        It 'rejects an empty -BannerText' {
            { Initialize-PwshProfile -BannerText '' } | Should -Throw
        }

        It 'warns and ignores banner params when the banner text resolves empty' {
            # The only way BannerText resolves empty (ValidateNotNullOrEmpty rejects an explicit '')
            # is an unset $env:COMPUTERNAME default. The banner is then suppressed; an explicitly
            # passed banner param must warn rather than vanish silently.
            $saved = $env:COMPUTERNAME
            try {
                $env:COMPUTERNAME = ''
                Initialize-PwshProfile -EnableAll -BannerColor Green -WarningVariable warnings -WarningAction SilentlyContinue
                Should -Invoke -ModuleName $script:Module Write-Figlet -Times 0 -Exactly
                $warnings | Should -Not -BeNullOrEmpty
            }
            finally { $env:COMPUTERNAME = $saved }
        }
    }

    Context 'theme selection and branding' {
        It 'uses the bundled screwcity theme and its branding by default' {
            Initialize-PwshProfile -EnableAll
            Should -Invoke -ModuleName $script:Module Enable-OhMyPosh -Times 1 -Exactly `
                -ParameterFilter { $Configuration -like '*screwcity.omp.json' }
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 1 -Exactly `
                -ParameterFilter { $Text -eq $env:COMPUTERNAME -and $Color -eq '#4c81c8' }
            Should -Invoke -ModuleName $script:Module Invoke-Step -Times 1 -Exactly `
                -ParameterFilter { $Description -eq 'Core' -and $Icon -eq ':nut_and_bolt:' }
        }

        It 'resolves -Theme forestcity to its bundled file and Forest City branding' {
            Initialize-PwshProfile -Theme forestcity -EnableAll
            Should -Invoke -ModuleName $script:Module Enable-OhMyPosh -Times 1 -Exactly `
                -ParameterFilter { $Configuration -like '*forestcity.omp.json' }
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 1 -Exactly `
                -ParameterFilter { $Text -eq $env:COMPUTERNAME -and $Color -eq '#8fce72' }
            Should -Invoke -ModuleName $script:Module Invoke-Step -Times 1 -Exactly `
                -ParameterFilter { $Description -eq 'Core' -and $Icon -eq ':deciduous_tree:' }
        }

        It 'lets an explicit banner value override the theme branding' {
            Initialize-PwshProfile -Theme forestcity -BannerColor Red -BannerText 'CUSTOM' -EnableAll
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 1 -Exactly `
                -ParameterFilter { $Text -eq 'CUSTOM' -and $Color -eq 'Red' }
        }

        It 'keeps the neutral screwcity branding for a -CustomTheme' {
            Initialize-PwshProfile -CustomTheme $script:ThemePath -EnableAll
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 1 -Exactly `
                -ParameterFilter { $Text -eq $env:COMPUTERNAME -and $Color -eq '#4c81c8' }
        }
    }

    Context 'validation' {
        It 'rejects an unknown -Enable token' {
            { Initialize-PwshProfile -Enable Nope } | Should -Throw
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
