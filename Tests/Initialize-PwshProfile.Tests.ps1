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
        Mock -ModuleName $script:Module Enable-Git { }
        Mock -ModuleName $script:Module Enable-OhMyPosh { }
        Mock -ModuleName $script:Module Enable-Zoxide { }
        Mock -ModuleName $script:Module Enable-Fzf { }
        Mock -ModuleName $script:Module Enable-FastNodeManager { }
        Mock -ModuleName $script:Module Enable-Xh { }
        Mock -ModuleName $script:Module Enable-Jq { }
        Mock -ModuleName $script:Module Enable-Bat { }
        Mock -ModuleName $script:Module Enable-Fd { }
        Mock -ModuleName $script:Module Enable-Ripgrep { }
        Mock -ModuleName $script:Module Enable-Less { }
        Mock -ModuleName $script:Module Enable-Lazygit { }
        Mock -ModuleName $script:Module Enable-Uv { }
        Mock -ModuleName $script:Module Enable-WingetCompletion { }
        Mock -ModuleName $script:Module Enable-AzureCliCompletion { }
        Mock -ModuleName $script:Module Enable-TailscaleCompletion { }
        Mock -ModuleName $script:Module Enable-DockerCompletion { }
        Mock -ModuleName $script:Module Enable-1PasswordCompletion { }
        Mock -ModuleName $script:Module Enable-GithubCliCompletion { }
    }

    Context 'runs the full startup' {
        It 'shows the banner and enables every tool with default arguments' {
            Initialize-PwshProfile
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 1 -Exactly
            # git is always-on (installed in Core, not a token).
            Should -Invoke -ModuleName $script:Module Enable-Git -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-OhMyPosh -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-Zoxide -Times 1 -Exactly -ParameterFilter { $Command -eq 'cd' }
            # fzf enables with the screwcity blend, full style, bat preview, PSFzf Ctrl+T/Ctrl+R
            # bindings, fd traversal, and git chords off (opt-in, off by default).
            Should -Invoke -ModuleName $script:Module Enable-Fzf -Times 1 -Exactly `
                -ParameterFilter { $Colors -like '*pointer:#c9aaff*' -and $Style -eq 'full' -and $Height -eq '~100%' -and $PreviewCommand -like 'bat *' -and `
                    $ProviderChord -eq 'Ctrl+t' -and $HistoryChord -eq 'Ctrl+r' -and $TabExpansionChord -eq 'Ctrl+Spacebar' -and $UseFd -and -not $GitKeyBindings }
            Should -Invoke -ModuleName $script:Module Enable-FastNodeManager -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-Xh -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-Jq -Times 1 -Exactly
            # bat enables with the screwcity blend theme and cat left intact.
            Should -Invoke -ModuleName $script:Module Enable-Bat -Times 1 -Exactly `
                -ParameterFilter { $Theme -eq 'Dracula' -and $Style -eq 'numbers,changes,header' -and -not $ReplaceCat }
            # fd enables with the screwcity LS_COLORS blend and fzf integration on.
            Should -Invoke -ModuleName $script:Module Enable-Fd -Times 1 -Exactly `
                -ParameterFilter { $LsColors -like '*di=1;38;2;201;170;255*' -and $IntegrateFzf }
            # ripgrep enables (install + completion only, no arguments).
            Should -Invoke -ModuleName $script:Module Enable-Ripgrep -Times 1 -Exactly
            # less enables with the pager-override left off.
            Should -Invoke -ModuleName $script:Module Enable-Less -Times 1 -Exactly `
                -ParameterFilter { -not $ReplaceMore -and -not $SetPager -and $Options -eq '-R -F -i' }
            # lazygit enables (install-only, no arguments).
            Should -Invoke -ModuleName $script:Module Enable-Lazygit -Times 1 -Exactly
            # uv enables (install + uv/uvx completion, no arguments).
            Should -Invoke -ModuleName $script:Module Enable-Uv -Times 1 -Exactly
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
            Initialize-PwshProfile -CustomTheme $script:ThemePath
            Should -Invoke -ModuleName $script:Module Enable-OhMyPosh -Times 1 -Exactly `
                -ParameterFilter { $Configuration -eq $ThemePath }
        }

        It 'forwards -ZoxideCommand to Enable-Zoxide as -Command' {
            Initialize-PwshProfile -ZoxideCommand 'z'
            Should -Invoke -ModuleName $script:Module Enable-Zoxide -Times 1 -Exactly `
                -ParameterFilter { $Command -eq 'z' }
        }

        It 'forwards -ReplaceCat and -BatStyle to Enable-Bat' {
            Initialize-PwshProfile -ReplaceCat -BatStyle 'plain'
            Should -Invoke -ModuleName $script:Module Enable-Bat -Times 1 -Exactly `
                -ParameterFilter { $ReplaceCat -and $Style -eq 'plain' }
        }

        It 'forwards -ReplaceMore to Enable-Less without implying the pager' {
            Initialize-PwshProfile -ReplaceMore
            Should -Invoke -ModuleName $script:Module Enable-Less -Times 1 -Exactly `
                -ParameterFilter { $ReplaceMore -and -not $SetPager }
        }

        It 'forwards -SetPager to Enable-Less without implying the more alias' {
            Initialize-PwshProfile -SetPager
            Should -Invoke -ModuleName $script:Module Enable-Less -Times 1 -Exactly `
                -ParameterFilter { $SetPager -and -not $ReplaceMore }
        }

        It 'forwards -LessOptions to Enable-Less as -Options' {
            Initialize-PwshProfile -LessOptions '-R'
            Should -Invoke -ModuleName $script:Module Enable-Less -Times 1 -Exactly `
                -ParameterFilter { $Options -eq '-R' }
        }

        It 'passes the default less options when none are supplied' {
            # The knob used to exist on Enable-Less but was never plumbed through the orchestrator,
            # so $env:LESS was effectively hardcoded. Guard against it drifting back to unpassed.
            Initialize-PwshProfile
            Should -Invoke -ModuleName $script:Module Enable-Less -Times 1 -Exactly `
                -ParameterFilter { $Options -eq '-R -F -i' }
        }

        It 'forwards -ReplaceHttp to Enable-Xh' {
            Initialize-PwshProfile -ReplaceHttp
            Should -Invoke -ModuleName $script:Module Enable-Xh -Times 1 -Exactly `
                -ParameterFilter { $ReplaceHttp }
        }

        It 'leaves http/https unclaimed by default' {
            Initialize-PwshProfile
            Should -Invoke -ModuleName $script:Module Enable-Xh -Times 1 -Exactly `
                -ParameterFilter { -not $ReplaceHttp }
        }

        It 'forwards an explicit -BatTheme, overriding the theme blend' {
            Initialize-PwshProfile -BatTheme 'Nord'
            Should -Invoke -ModuleName $script:Module Enable-Bat -Times 1 -Exactly `
                -ParameterFilter { $Theme -eq 'Nord' }
        }

        It 'blends bat with the forestcity theme by default' {
            Initialize-PwshProfile -Theme forestcity
            Should -Invoke -ModuleName $script:Module Enable-Bat -Times 1 -Exactly `
                -ParameterFilter { $Theme -eq 'gruvbox-dark' }
        }

        It 'blends fd and fzf with the forestcity palette by default' {
            Initialize-PwshProfile -Theme forestcity
            Should -Invoke -ModuleName $script:Module Enable-Fd -Times 1 -Exactly `
                -ParameterFilter { $LsColors -like '*di=1;38;2;143;206;114*' }
            Should -Invoke -ModuleName $script:Module Enable-Fzf -Times 1 -Exactly `
                -ParameterFilter { $Colors -like '*pointer:#8fce72*' }
        }

        It 'forwards explicit -FdColors and -FzfColors, overriding the theme blend' {
            Initialize-PwshProfile -FdColors 'di=0' -FzfColors 'pointer:#ff0000'
            Should -Invoke -ModuleName $script:Module Enable-Fd -Times 1 -Exactly `
                -ParameterFilter { $LsColors -eq 'di=0' }
            Should -Invoke -ModuleName $script:Module Enable-Fzf -Times 1 -Exactly `
                -ParameterFilter { $Colors -eq 'pointer:#ff0000' }
        }

        It 'leaves fzf git chords unbound by default and forwards the default tab chord' {
            Initialize-PwshProfile
            Should -Invoke -ModuleName $script:Module Enable-Fzf -Times 1 -Exactly `
                -ParameterFilter { -not $GitKeyBindings -and $TabExpansionChord -eq 'Ctrl+Spacebar' }
        }

        It 'binds fzf git chords when -FzfGitKeyBindings is passed' {
            Initialize-PwshProfile -FzfGitKeyBindings
            Should -Invoke -ModuleName $script:Module Enable-Fzf -Times 1 -Exactly `
                -ParameterFilter { $GitKeyBindings }
        }

        It 'forwards -FzfTabChord to Enable-Fzf as -TabExpansionChord' {
            Initialize-PwshProfile -FzfTabChord 'Ctrl+j'
            Should -Invoke -ModuleName $script:Module Enable-Fzf -Times 1 -Exactly `
                -ParameterFilter { $TabExpansionChord -eq 'Ctrl+j' }
        }

        It 'forwards -StepIcon to the top-level Invoke-Step calls' {
            Initialize-PwshProfile -StepIcon '🚀'
            Should -Invoke -ModuleName $script:Module Invoke-Step -Times 1 -Exactly `
                -ParameterFilter { $Description -eq 'Core' -and $Icon -eq '🚀' }
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

    Context 'every tool runs unconditionally' {
        It 'renders both the Core and WinGet sections' {
            Initialize-PwshProfile
            Should -Invoke -ModuleName $script:Module Invoke-Step -Times 1 -Exactly `
                -ParameterFilter { $Description -eq 'Core' }
            # The WinGet section no longer depends on a selection, so it always renders.
            Should -Invoke -ModuleName $script:Module Invoke-Step -Times 1 -Exactly `
                -ParameterFilter { $Description -eq 'WinGet' }
        }

        It 'runs every catalog tool exactly once' {
            # The invariant that replaced the -Enable guards: no tool can be skipped, so each enabler
            # is invoked once per startup.
            Initialize-PwshProfile
            foreach ($fn in 'Enable-Zoxide', 'Enable-Fzf', 'Enable-FastNodeManager', 'Enable-Xh',
                'Enable-Jq', 'Enable-Bat', 'Enable-Fd', 'Enable-Ripgrep', 'Enable-Less', 'Enable-Lazygit',
                'Enable-Uv') {
                Should -Invoke -ModuleName $script:Module $fn -Times 1 -Exactly
            }
            Should -Invoke -ModuleName $script:Module Initialize-PSReadline -Times 1 -Exactly
        }

        It 'always wires fzf to fd and a bat preview' {
            # Formerly derived from co-enablement; now constant, since fd and bat are always present.
            Initialize-PwshProfile
            Should -Invoke -ModuleName $script:Module Enable-Fzf -Times 1 -Exactly `
                -ParameterFilter { $UseFd -and $PreviewCommand -like 'bat *' }
            Should -Invoke -ModuleName $script:Module Enable-Fd -Times 1 -Exactly `
                -ParameterFilter { $IntegrateFzf }
        }

        It 'always registers the shell completions' {
            Initialize-PwshProfile
            Should -Invoke -ModuleName $script:Module Enable-WingetCompletion -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Enable-GithubCliCompletion -Times 1 -Exactly
        }
    }

    Context 'tool-specific parameters never warn' {
        It 'stays quiet when a tool-owned parameter is supplied' {
            # There is no longer any such thing as a parameter for a tool that is not enabled, so the
            # old param/tool coupling warning has nothing to fire on.
            Initialize-PwshProfile -ReplaceCat -ReplaceMore -FzfTabChord 'Ctrl+j' -FzfGitKeyBindings `
                -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings | Should -BeNullOrEmpty
            Should -Invoke -ModuleName $script:Module Enable-Bat -Times 1 -Exactly -ParameterFilter { $ReplaceCat }
            Should -Invoke -ModuleName $script:Module Enable-Less -Times 1 -Exactly -ParameterFilter { $ReplaceMore }
            Should -Invoke -ModuleName $script:Module Enable-Fzf -Times 1 -Exactly `
                -ParameterFilter { $GitKeyBindings -and $TabExpansionChord -eq 'Ctrl+j' }
        }
    }

    Context 'banner control' {
        It 'renders no banner under -NoBanner' {
            Initialize-PwshProfile -NoBanner
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 0 -Exactly
        }

        It 'warns and ignores banner params passed with -NoBanner' {
            Initialize-PwshProfile -NoBanner -BannerColor Green -WarningVariable warnings -WarningAction SilentlyContinue
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
                Initialize-PwshProfile -BannerColor Green -WarningVariable warnings -WarningAction SilentlyContinue
                Should -Invoke -ModuleName $script:Module Write-Figlet -Times 0 -Exactly
                $warnings | Should -Not -BeNullOrEmpty
            }
            finally { $env:COMPUTERNAME = $saved }
        }
    }

    Context 'theme selection and branding' {
        It 'uses the bundled screwcity theme and its branding by default' {
            Initialize-PwshProfile
            Should -Invoke -ModuleName $script:Module Enable-OhMyPosh -Times 1 -Exactly `
                -ParameterFilter { $Configuration -like '*screwcity.omp.json' }
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 1 -Exactly `
                -ParameterFilter { $Text -eq $env:COMPUTERNAME -and $Color -eq '#4c81c8' }
            Should -Invoke -ModuleName $script:Module Invoke-Step -Times 1 -Exactly `
                -ParameterFilter { $Description -eq 'Core' -and $Icon -eq ':nut_and_bolt:' }
        }

        It 'resolves -Theme forestcity to its bundled file and Forest City branding' {
            Initialize-PwshProfile -Theme forestcity
            Should -Invoke -ModuleName $script:Module Enable-OhMyPosh -Times 1 -Exactly `
                -ParameterFilter { $Configuration -like '*forestcity.omp.json' }
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 1 -Exactly `
                -ParameterFilter { $Text -eq $env:COMPUTERNAME -and $Color -eq '#8fce72' }
            Should -Invoke -ModuleName $script:Module Invoke-Step -Times 1 -Exactly `
                -ParameterFilter { $Description -eq 'Core' -and $Icon -eq ':deciduous_tree:' }
        }

        It 'lets an explicit banner value override the theme branding' {
            Initialize-PwshProfile -Theme forestcity -BannerColor Red -BannerText 'CUSTOM'
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 1 -Exactly `
                -ParameterFilter { $Text -eq 'CUSTOM' -and $Color -eq 'Red' }
        }

        It 'keeps the neutral screwcity branding for a -CustomTheme' {
            Initialize-PwshProfile -CustomTheme $script:ThemePath
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 1 -Exactly `
                -ParameterFilter { $Text -eq $env:COMPUTERNAME -and $Color -eq '#4c81c8' }
        }
    }

    Context 'retired and unrecognized arguments' {
        It 'emits no warning for a normal call' {
            # THE regression guard. With no remaining arguments $LegacyArgument is $null, and
            # $null.Count throws under Set-StrictMode -Version Latest -- which this suite runs. A
            # .Count-based guard would make the shim throw on every single startup, which is the exact
            # failure it exists to prevent. Keep this first.
            Initialize-PwshProfile -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings | Should -BeNullOrEmpty
        }

        It 'does not throw on a retired parameter' {
            # Every profile block written before the tool-selection parameters were retired passes
            # -Enable or -EnableAll. Binding would fail before the body ran, so startup would produce
            # nothing at all -- no prompt, no tools -- violating "never throw out of profile startup".
            # Note: no -WarningVariable here. A scriptblock is its own scope, so a -WarningVariable
            # set inside one never reaches the test; the warning text is asserted separately below.
            { Initialize-PwshProfile -EnableAll -WarningAction SilentlyContinue } | Should -Not -Throw
        }

        It 'warns about a retired parameter and still runs startup' {
            Initialize-PwshProfile -EnableAll -WarningVariable warnings -WarningAction SilentlyContinue
            "$warnings" | Should -BeLike '*-EnableAll*'
            "$warnings" | Should -BeLike '*Install-PwshProfile*'
            # Startup still actually ran.
            Should -Invoke -ModuleName $script:Module Enable-OhMyPosh -Times 1 -Exactly
        }

        It 'swallows a retired parameter''s value along with the flag' {
            Initialize-PwshProfile -Enable Zoxide, Bat -WarningVariable warnings -WarningAction SilentlyContinue
            "$warnings" | Should -BeLike '*-Enable*'
            Should -Invoke -ModuleName $script:Module Enable-OhMyPosh -Times 1 -Exactly
        }

        It 'still binds the valid parameters alongside a retired one' {
            Initialize-PwshProfile -Theme forestcity -EnableAll -ReplaceCat `
                -WarningVariable warnings -WarningAction SilentlyContinue
            Should -Invoke -ModuleName $script:Module Enable-Bat -Times 1 -Exactly `
                -ParameterFilter { $Theme -eq 'gruvbox-dark' -and $ReplaceCat }
        }

        It 'reports an unrecognized argument as a possible typo, not a stale profile' {
            # Different cause, different fix: a typo needs correcting, a retired name needs a re-run.
            Initialize-PwshProfile -BannerColur Green -WarningVariable warnings -WarningAction SilentlyContinue
            "$warnings" | Should -BeLike '*-BannerColur*'
            "$warnings" | Should -BeLike '*typo*'
        }

        It 'does not let a typo''s value land on the positional -BannerText' {
            # -BannerText is Position 0, so the danger is `-BannerColur Green` quietly renaming the
            # banner to "Green". The binder absorbs the flag and its value together instead.
            Initialize-PwshProfile -BannerColur Green -WarningVariable warnings -WarningAction SilentlyContinue
            Should -Invoke -ModuleName $script:Module Write-Figlet -Times 1 -Exactly `
                -ParameterFilter { $Text -ne 'Green' }
        }
    }

    Context 'validation' {
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
