#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'

    # Calls the private writer in module scope, threading the (test-scoped) path/args through
    # InModuleScope -Parameters so the body never closes over the test scope. Defined here (not
    # at file top level) so it exists during the run phase, not just discovery.
    function Invoke-Writer {
        param(
            [string]$Path,
            [string]$Call = 'Initialize-PwshProfile',
            [switch]$Force,
            [switch]$WhatIf
        )
        InModuleScope ScrewCitySoftware.PwshProfile -Parameters @{ P = $Path; C = $Call; F = [bool]$Force; W = [bool]$WhatIf } {
            param($P, $C, $F, $W)
            $a = @{ Path = $P; InitializeCall = $C }
            if ($F) { $a.Force = $true }
            if ($W) { $a.WhatIf = $true }
            Write-PwshProfileBlock @a
        }
    }
}

Describe 'Build-PwshProfileInitializeCall' {
    It 'returns a bare call for default settings' {
        InModuleScope $script:Module {
            Build-PwshProfileInitializeCall -Setting (Get-PwshProfileDefault) |
                Should -Be 'Initialize-PwshProfile'
        }
    }

    It 'emits only changed scalar parameters, single-quoted' {
        InModuleScope $script:Module {
            $s = Get-PwshProfileDefault
            $s.BannerColor = '#00d7ff'
            Build-PwshProfileInitializeCall -Setting $s |
                Should -Be "Initialize-PwshProfile -BannerColor '#00d7ff'"
        }
    }

    It 'does not emit the default banner font' {
        InModuleScope $script:Module {
            $s = Get-PwshProfileDefault
            $s.BannerFont = 'ANSIShadow'   # the default — should be omitted
            $s.BannerColor = '#00d7ff'     # a non-default dimension so the call isn't bare
            # The default font must be absent even though another param forces a non-bare call.
            Build-PwshProfileInitializeCall -Setting $s |
                Should -Be "Initialize-PwshProfile -BannerColor '#00d7ff'"
        }
    }

    It 'emits a non-default banner font' {
        InModuleScope $script:Module {
            $s = Get-PwshProfileDefault
            $s.BannerFont = 'Doom'
            Build-PwshProfileInitializeCall -Setting $s |
                Should -Be "Initialize-PwshProfile -BannerFont 'Doom'"
        }
    }

    It 'emits Skip and SkipSection as comma-joined tokens' {
        InModuleScope $script:Module {
            $s = Get-PwshProfileDefault
            $s.Skip = @('Fnm', 'Xh')
            $s.SkipSection = @('Shell')
            Build-PwshProfileInitializeCall -Setting $s |
                Should -Be 'Initialize-PwshProfile -Skip Fnm,Xh -SkipSection Shell'
        }
    }

    It 'doubles embedded single quotes in single-quoted params' {
        InModuleScope $script:Module {
            $s = Get-PwshProfileDefault
            $s.StepIcon = ":o'clock:"
            Build-PwshProfileInitializeCall -Setting $s |
                Should -Be "Initialize-PwshProfile -StepIcon ':o''clock:'"
        }
    }

    It 'double-quotes BannerText so it interpolates at startup' {
        InModuleScope $script:Module {
            # '$env:COMPUTERNAME' is now the default (omitted), so use a different $env token to
            # exercise the double-quoting path.
            $s = Get-PwshProfileDefault
            $s.BannerText = '$env:USERNAME'
            Build-PwshProfileInitializeCall -Setting $s |
                Should -Be 'Initialize-PwshProfile -BannerText "$env:USERNAME"'
        }
    }

    It 'backtick-escapes embedded double quotes in BannerText' {
        InModuleScope $script:Module {
            $s = Get-PwshProfileDefault
            $s.BannerText = 'Say "hi"'
            Build-PwshProfileInitializeCall -Setting $s |
                Should -Be 'Initialize-PwshProfile -BannerText "Say `"hi`""'
        }
    }

    It 'emits only -Theme for a forestcity default (its branding is the themed baseline)' {
        InModuleScope $script:Module {
            Build-PwshProfileInitializeCall -Setting (Get-PwshProfileDefault -Theme forestcity) |
                Should -Be 'Initialize-PwshProfile -Theme forestcity'
        }
    }

    It 'emits -Theme alongside an overridden banner value' {
        InModuleScope $script:Module {
            $s = Get-PwshProfileDefault -Theme forestcity
            $s.BannerColor = '#00d7ff'
            Build-PwshProfileInitializeCall -Setting $s |
                Should -Be "Initialize-PwshProfile -Theme forestcity -BannerColor '#00d7ff'"
        }
    }

    It 'emits -CustomTheme (single-quoted) and never -Theme for a custom theme path' {
        InModuleScope $script:Module {
            $s = Get-PwshProfileDefault
            $s.CustomTheme = '~/my.omp.json'
            Build-PwshProfileInitializeCall -Setting $s |
                Should -Be "Initialize-PwshProfile -CustomTheme '~/my.omp.json'"
        }
    }
}

Describe 'Get-SpectreColorValue' {
    It 'parses a hex string into the matching Spectre color' {
        InModuleScope $script:Module {
            $c = Get-SpectreColorValue '#8fce72'
            $c | Should -BeOfType ([Spectre.Console.Color])
            $c | Should -Be ([Spectre.Console.Color]::FromHex('#8fce72'))
        }
    }

    It 'resolves a named Spectre color without throwing' {
        InModuleScope $script:Module {
            $c = Get-SpectreColorValue 'Silver'
            $c | Should -BeOfType ([Spectre.Console.Color])
            $c | Should -Be ([Spectre.Console.Color]::Silver)
        }
    }

    It 'falls back to the default color for empty or unrecognized input' {
        InModuleScope $script:Module {
            Get-SpectreColorValue '' | Should -Be ([Spectre.Console.Color]::Default)
            Get-SpectreColorValue 'not-a-color' | Should -Be ([Spectre.Console.Color]::Default)
        }
    }
}

Describe 'Format-PwshProfileColorValue' {
    It 'renders a hex value as a swatch tinted with the same hex' {
        InModuleScope $script:Module {
            $out = Format-PwshProfileColorValue '#c9aaff'
            $out | Should -Match '███'
            $out | Should -Match '\[#c9aaff\]'
            $out | Should -Match '#c9aaff'
        }
    }

    It 'normalizes a hex value with no leading # to a valid swatch tag' {
        InModuleScope $script:Module {
            $out = Format-PwshProfileColorValue 'c9aaff'
            $out | Should -Match '\[#c9aaff\]███\[/\]'
        }
    }

    It 'renders a named color as a swatch (resolved to its hex)' {
        InModuleScope $script:Module {
            $hex = ([Spectre.Console.Color]::Silver).ToHex()
            $out = Format-PwshProfileColorValue 'Silver'
            $out | Should -Match '███'
            $out | Should -Match ([regex]::Escape("[#$hex]"))
        }
    }

    It 'returns the plain escaped value (no swatch) for empty or unrecognized input' {
        InModuleScope $script:Module {
            Format-PwshProfileColorValue '' | Should -Be ''
            $out = Format-PwshProfileColorValue 'not-a-color'
            $out | Should -Be 'not-a-color'
            $out | Should -Not -Match '███'
        }
    }

    It 'escapes markup brackets in an unrecognized value' {
        InModuleScope $script:Module {
            Format-PwshProfileColorValue '[x]' | Should -Be '[[x]]'
        }
    }
}

Describe 'Read-PwshProfileSettingChange' {
    It 'renders a Color-flagged row value as a swatch' {
        InModuleScope $script:Module {
            Mock Write-SpectreHost { }
            Mock Read-SpectreConfirm { $false } -RemoveParameterType 'Color'
            $rows = @([pscustomobject]@{ Label = 'Color'; Value = '#c9aaff'; Recommended = '#c9aaff'; Color = $true })
            Read-PwshProfileSettingChange -Message 'Change?' -Row $rows | Out-Null
            # The swatch is the hex tag immediately wrapping the blocks (distinct from the accent tag
            # on the • glyph); -match is case-insensitive, so it tolerates ToHex's uppercase output.
            Should -Invoke Write-SpectreHost -Times 1 -Exactly -ParameterFilter {
                $Message -match '\[#c9aaff\]███'
            }
        }
    }

    It 'renders a non-color row value as plain escaped text (no swatch)' {
        InModuleScope $script:Module {
            Mock Write-SpectreHost { }
            Mock Read-SpectreConfirm { $false } -RemoveParameterType 'Color'
            $rows = @([pscustomobject]@{ Label = 'Default scope'; Value = 'machine'; Recommended = 'user' })
            Read-PwshProfileSettingChange -Message 'Change?' -Row $rows | Out-Null
            Should -Invoke Write-SpectreHost -Times 1 -Exactly -ParameterFilter {
                $Message.Contains('machine') -and -not $Message.Contains('███')
            }
        }
    }
}

Describe 'Format-PwshProfileHelpMarkup' {
    It 'wraps **term** in the accent color' {
        InModuleScope $script:Module {
            Format-PwshProfileHelpMarkup -Text 'use **zoxide** now' |
                Should -Be '[grey]use [#c9aaff]zoxide[/] now[/]'
        }
    }

    It 'wraps `code` in the code color' {
        InModuleScope $script:Module {
            Format-PwshProfileHelpMarkup -Text 'type `cd` here' |
                Should -Be '[grey]type [#5fd7ff]cd[/] here[/]'
        }
    }

    It 'honors custom accent and code colors' {
        InModuleScope $script:Module {
            Format-PwshProfileHelpMarkup -Text '**a** `b`' -Accent 'Red' -Code 'Blue' -Body 'Green' |
                Should -Be '[Green][Red]a[/] [Blue]b[/][/]'
        }
    }

    It 'escapes literal markup brackets in body text' {
        InModuleScope $script:Module {
            Format-PwshProfileHelpMarkup -Text 'an [example]' | Should -Match '\[\[example\]\]'
        }
    }

    It 'escapes literal brackets inside emphasized spans' {
        InModuleScope $script:Module {
            Format-PwshProfileHelpMarkup -Text '**[x]**' | Should -Be '[grey][#c9aaff][[x]][/][/]'
        }
    }

    It 'omits the body wrapper when Body is default' {
        InModuleScope $script:Module {
            Format-PwshProfileHelpMarkup -Text 'custom: **forestcity**' -Body default |
                Should -Be 'custom: [#c9aaff]forestcity[/]'
        }
    }

    It 'returns an empty (wrapped) string for empty input' {
        InModuleScope $script:Module {
            Format-PwshProfileHelpMarkup -Text '' | Should -Be '[grey][/]'
        }
    }
}

Describe 'Write-PwshProfilePromptAnswer' {
    It 'echoes a check mark and the escaped value via Write-SpectreHost' {
        InModuleScope $script:Module {
            Mock Write-SpectreHost { }
            Write-PwshProfilePromptAnswer -Value 'Center'
            Should -Invoke Write-SpectreHost -Times 1 -Exactly -ParameterFilter {
                $Message.Contains('✓') -and $Message.Contains('Center')
            }
        }
    }

    It 'escapes markup brackets in the value' {
        InModuleScope $script:Module {
            Mock Write-SpectreHost { }
            Write-PwshProfilePromptAnswer -Value '[x]'
            Should -Invoke Write-SpectreHost -Times 1 -Exactly -ParameterFilter { $Message.Contains('[[x]]') }
        }
    }
}

Describe 'Write-PwshProfileBlock' {
    BeforeEach {
        $script:Dir = Join-Path ([System.IO.Path]::GetTempPath()) ('sc-prof-' + [guid]::NewGuid())
        $script:Dest = Join-Path $script:Dir 'profile.ps1'
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:Dir) { Remove-Item -LiteralPath $script:Dir -Recurse -Force }
    }

    It 'creates the file and its missing parent directory' {
        $r = Invoke-Writer -Path $script:Dest
        Test-Path -LiteralPath $script:Dest | Should -BeTrue
        $r.Action | Should -Be 'Created'
        $r.Changed | Should -BeTrue
    }

    It 'writes both markers and the exact bootstrap lines' {
        Invoke-Writer -Path $script:Dest | Out-Null
        $c = Get-Content -LiteralPath $script:Dest -Raw
        $c | Should -Match '# >>> ScrewCitySoftware\.PwshProfile bootstrap >>>'
        $c | Should -Match '# <<< ScrewCitySoftware\.PwshProfile bootstrap <<<'
        $c | Should -Match 'Import-Module ScrewCitySoftware\.PwshProfile'
        $c | Should -Match 'Initialize-PwshProfile'
    }

    It 'includes guidance comments pointing at Install and Uninstall' {
        Invoke-Writer -Path $script:Dest | Out-Null
        $c = Get-Content -LiteralPath $script:Dest -Raw
        $c | Should -Match '#.*Install-PwshProfile'
        $c | Should -Match '#.*Uninstall-PwshProfile'
    }

    It 'writes UTF-8 without a BOM' {
        Invoke-Writer -Path $script:Dest | Out-Null
        $bytes = [System.IO.File]::ReadAllBytes($script:Dest)
        ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -BeFalse
    }

    It 'starts an empty file with the marker (no leading blank line)' {
        New-Item -ItemType Directory -Path $script:Dir | Out-Null
        Set-Content -LiteralPath $script:Dest -Value '' -NoNewline
        Invoke-Writer -Path $script:Dest | Out-Null
        Get-Content -LiteralPath $script:Dest -Raw | Should -Match '^# >>> ScrewCitySoftware'
    }

    It 'prepends the block and preserves existing content below it' {
        New-Item -ItemType Directory -Path $script:Dir | Out-Null
        Set-Content -LiteralPath $script:Dest -Value "Write-Host 'mine'"
        $r = Invoke-Writer -Path $script:Dest
        $c = Get-Content -LiteralPath $script:Dest -Raw
        $c | Should -Match '^# >>> ScrewCitySoftware'
        $c | Should -Match "Write-Host 'mine'"
        $c.IndexOf('# >>>') | Should -BeLessThan $c.IndexOf("Write-Host 'mine'")
        $r.Action | Should -Be 'Prepended'
    }

    It 'replaces an existing managed block in place on re-run, preserving surrounding content' {
        New-Item -ItemType Directory -Path $script:Dir | Out-Null
        Set-Content -LiteralPath $script:Dest -Value "# top comment`nWrite-Host 'mine'"
        Invoke-Writer -Path $script:Dest -Call 'Initialize-PwshProfile' | Out-Null
        $r2 = Invoke-Writer -Path $script:Dest -Call 'Initialize-PwshProfile -Skip Xh'
        $c = Get-Content -LiteralPath $script:Dest -Raw
        ([regex]::Matches($c, '# >>> ScrewCitySoftware\.PwshProfile bootstrap >>>')).Count | Should -Be 1
        $c | Should -Match 'Initialize-PwshProfile -Skip Xh'
        $c | Should -Match '# top comment'
        $c | Should -Match "Write-Host 'mine'"
        $r2.Action | Should -Be 'Replaced'
        $r2.Changed | Should -BeTrue
    }

    It 'is idempotent: re-running with identical settings makes no change' {
        Invoke-Writer -Path $script:Dest | Out-Null
        $before = Get-Content -LiteralPath $script:Dest -Raw
        $r2 = Invoke-Writer -Path $script:Dest
        $r2.Action | Should -Be 'AlreadyPresent'
        $r2.Changed | Should -BeFalse
        Get-Content -LiteralPath $script:Dest -Raw | Should -BeExactly $before
    }

    It 'leaves a hand-written bare import untouched (BareImportPresent)' {
        New-Item -ItemType Directory -Path $script:Dir | Out-Null
        Set-Content -LiteralPath $script:Dest -Value "Import-Module ScrewCitySoftware.PwshProfile`nInitialize-PwshProfile"
        $r = Invoke-Writer -Path $script:Dest
        $r.Action | Should -Be 'BareImportPresent'
        $r.Changed | Should -BeFalse
        Get-Content -LiteralPath $script:Dest -Raw | Should -Not -Match '# >>>'
    }

    It 'prepends over a bare import when -Force is given' {
        New-Item -ItemType Directory -Path $script:Dir | Out-Null
        Set-Content -LiteralPath $script:Dest -Value 'Import-Module ScrewCitySoftware.PwshProfile'
        $r = Invoke-Writer -Path $script:Dest -Force
        $r.Action | Should -Be 'ForcePrepended'
        $r.Changed | Should -BeTrue
        Get-Content -LiteralPath $script:Dest -Raw | Should -Match '# >>>'
    }

    It 'makes no change under -WhatIf' {
        Invoke-Writer -Path $script:Dest -WhatIf | Out-Null
        Test-Path -LiteralPath $script:Dest | Should -BeFalse
    }

    It 'throws when the path is an existing directory' {
        New-Item -ItemType Directory -Path $script:Dir | Out-Null
        { Invoke-Writer -Path $script:Dir } | Should -Throw '*is a directory*'
    }
}

Describe 'Invoke-PwshProfileWizard' {
    # Sets the common mocks for one forward pass that submits at the review hub: screwcity theme,
    # banner shown (text prompts accept their pre-filled defaults), default icon, fonts declined.
    # Individual tests override specific mocks (theme, banner confirm, feature tree, hub choice).
    BeforeEach {
        InModuleScope $script:Module {
            # Each step opens with Write-PwshProfileStepHeader, which pipes Format-SpectrePanel to
            # Out-Host internally; the mocked Format-SpectrePanel neutralizes it (see the leak test).
            Mock Format-SpectrePanel { } -RemoveParameterType 'Color'
            Mock Write-SpectreHost { }
            Mock Read-SpectreText { $DefaultAnswer }
            # Banner: shown by default; Nerd Fonts: declined by default.
            Mock Read-SpectreConfirm { $false } -RemoveParameterType 'Color'
            Mock Read-SpectreConfirm { $true } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Show a startup banner?' }
            # Open both "make changes?" gates by default so the per-setting prompts below run; the
            # gate-closed paths get their own tests.
            Mock Read-SpectreConfirm { $true } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Change these banner settings?' }
            Mock Read-SpectreConfirm { $true } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Change these winget settings?' }
            # Selections, keyed by prompt message.
            Mock Read-SpectreSelection { [pscustomobject]@{ Label = 'screwcity'; Theme = 'screwcity'; Custom = $false } } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Choose an oh-my-posh theme' }
            Mock Read-SpectreSelection { 'Left' } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Banner alignment' }
            Mock Read-SpectreSelection { 'ANSIShadow' } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Banner font' }
            Mock Read-SpectreSelection { [pscustomobject]@{ Label = 'x'; Icon = ':nut_and_bolt:' } } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Step marker icon' }
            # Winget step: seed from a fixed default and accept the floated-current choices ($Choices[0]).
            # The catch-all Read-SpectreConfirm { $false } above covers the two winget confirms.
            Mock Get-WingetSettingDefault { @{ Scope = 'user'; ProgressBar = 'rainbow'; AnonymizePath = $true; DisableInstallNote = $false } }
            Mock Read-SpectreSelection { $Choices[0] } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Default install scope (winget)' }
            Mock Read-SpectreSelection { $Choices[0] } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Winget progress bar style' }
            # Feature tree: everything enabled. Hub: submit (the first choice).
            Mock Read-PwshProfileFeatureTree { @('PSReadLine', 'TerminalIcons', 'PoshGit', 'Zoxide', 'Fzf', 'Fnm', 'Xh', 'Completions') } -RemoveParameterType 'Color'
            Mock Read-SpectreSelection { $Choices[0] } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'What would you like to do?' }
        }
    }

    It 'returns the theme defaults with no feature skips when everything stays enabled' {
        InModuleScope $script:Module {
            $s = Invoke-PwshProfileWizard
            $s.BannerText | Should -Be '$env:COMPUTERNAME'
            $s.BannerColor | Should -Be '#c9aaff'
            $s.StepIcon | Should -Be ':nut_and_bolt:'
            @($s.Skip).Count | Should -Be 0
            @($s.SkipSection).Count | Should -Be 0
            $s.NerdFont | Should -BeNullOrEmpty
        }
    }

    It 'maps unchecked features to Skip' {
        InModuleScope $script:Module {
            Mock Read-SpectreSelection { 'Center' } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Banner alignment' }
            Mock Read-SpectreSelection { [pscustomobject]@{ Label = 'x'; Icon = ':gear:' } } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Step marker icon' }
            # Fnm, Xh and Completions left unchecked; the rest enabled.
            Mock Read-PwshProfileFeatureTree { @('PSReadLine', 'TerminalIcons', 'PoshGit', 'Zoxide', 'Fzf') } -RemoveParameterType 'Color'

            $s = Invoke-PwshProfileWizard
            $s.StepIcon | Should -Be ':gear:'
            $s.BannerAlignment | Should -Be 'Center'
            $s.Skip | Should -Contain 'Fnm'
            $s.Skip | Should -Contain 'Xh'
            $s.Skip | Should -Contain 'Completions'
            $s.Skip | Should -Not -Contain 'PSReadLine'
            $s.Skip | Should -Not -Contain 'Banner'
            $s.Skip | Should -Not -Contain 'Zoxide'
            @($s.SkipSection).Count | Should -Be 0
            $s.ZoxideCommand | Should -Be 'cd'
        }
    }

    It 'adds Banner to Skip and skips the theming sub-steps when the banner is declined' {
        InModuleScope $script:Module {
            Mock Read-SpectreConfirm { $false } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Show a startup banner?' }

            $s = Invoke-PwshProfileWizard
            $s.Skip | Should -Contain 'Banner'
            # Banner text keeps the default machine-name value (the prompts never ran).
            $s.BannerText | Should -Be '$env:COMPUTERNAME'
            Should -Invoke Read-SpectreSelection -Times 0 -Exactly -ParameterFilter { $Message -eq 'Banner alignment' }
        }
    }

    It 'selecting forestcity sets the theme and its Forest City branding' {
        InModuleScope $script:Module {
            Mock Read-SpectreSelection { [pscustomobject]@{ Label = 'forestcity'; Theme = 'forestcity'; Custom = $false } } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Choose an oh-my-posh theme' }
            # Accept the floated default icon (deciduous tree for forestcity).
            Mock Read-SpectreSelection { [pscustomobject]@{ Label = 'x'; Icon = ':deciduous_tree:' } } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Step marker icon' }

            $s = Invoke-PwshProfileWizard
            $s.Theme | Should -Be 'forestcity'
            $s.BannerText | Should -Be '$env:COMPUTERNAME'
            $s.BannerColor | Should -Be '#8fce72'
            $s.StepIcon | Should -Be ':deciduous_tree:'
        }
    }

    It 'choosing a custom path records CustomTheme and seeds neutral branding' {
        InModuleScope $script:Module {
            $custom = Join-Path ([System.IO.Path]::GetTempPath()) 'sc-wiz-custom.omp.json'
            Set-Content -Path $custom -Value '{}' -Force
            try {
                Mock Read-SpectreSelection { [pscustomobject]@{ Label = 'Custom path…'; Theme = $null; Custom = $true } } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Choose an oh-my-posh theme' }
                Mock Read-SpectreText { $custom } -ParameterFilter { $Message -like 'Path to your custom*' }
                # Accept the floated default icon (the generic gear seeded for a custom theme).
                Mock Read-SpectreSelection { [pscustomobject]@{ Label = 'x'; Icon = ':gear:' } } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Step marker icon' }

                $s = Invoke-PwshProfileWizard
                $s.CustomTheme | Should -Be $custom
                $s.Theme | Should -Be 'screwcity'
                # Neutral color/icon seeds; banner text keeps the uniform machine-name default.
                $s.BannerText | Should -Be '$env:COMPUTERNAME'
                $s.BannerColor | Should -Be 'Silver'
                $s.StepIcon | Should -Be ':gear:'
            }
            finally { Remove-Item -Path $custom -ErrorAction SilentlyContinue }
        }
    }

    It 'returns $null when the user cancels at the review hub' {
        InModuleScope $script:Module {
            # Cancel is the last hub choice.
            Mock Read-SpectreSelection { $Choices[-1] } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'What would you like to do?' }

            $s = Invoke-PwshProfileWizard
            $s | Should -BeNullOrEmpty
        }
    }

    It 'returns a hashtable even when the step-header panel leaks to the pipeline' {
        InModuleScope $script:Module {
            # The real Format-SpectrePanel emits its rendered string to the pipeline; Write-PwshProfileStepHeader
            # pipes it to Out-Host so it never escapes. Simulate the panel output with a sentinel: without
            # the Out-Host inside the header helper, this would leak through the bare step calls and the
            # result would become Object[] instead of a hashtable.
            Mock Format-SpectrePanel { 'LEAKED-PANEL' } -RemoveParameterType 'Color'

            $s = Invoke-PwshProfileWizard
            $s | Should -BeOfType ([hashtable])
            $s.BannerText | Should -Be '$env:COMPUTERNAME'
        }
    }

    It 'installs the recommended Meslo + CascadiaCode set when the user opts in' -Skip:(-not (Get-Command Get-NerdFont -ErrorAction SilentlyContinue)) {
        InModuleScope $script:Module {
            Mock Import-ModuleSafe { }
            Mock Get-NerdFont { @([pscustomobject]@{ Name = 'Meslo' }, [pscustomobject]@{ Name = 'CascadiaCode' }, [pscustomobject]@{ Name = 'JetBrainsMono' }) }
            # Opt in to fonts — a single yes/no installs the recommended pair (banner stays yes from BeforeEach).
            Mock Read-SpectreConfirm { $true } -RemoveParameterType 'Color' -ParameterFilter { $Message -like 'Install Nerd Fonts*' }

            $s = Invoke-PwshProfileWizard
            @($s.NerdFont).Count | Should -Be 2
            $s.NerdFont | Should -Contain 'Meslo'
            $s.NerdFont | Should -Contain 'CascadiaCode'
        }
    }

    It 'seeds the winget settings from Get-WingetSettingDefault and keeps the floated current values' {
        InModuleScope $script:Module {
            $s = Invoke-PwshProfileWizard
            # Accepting $Choices[0] keeps the seeded current value (user / rainbow).
            $s.WingetScope | Should -Be 'user'
            $s.WingetProgressBar | Should -Be 'rainbow'
            # The catch-all Read-SpectreConfirm { $false } answers both winget confirms.
            $s.WingetAnonymizePath | Should -BeFalse
            $s.WingetDisableInstallNote | Should -BeFalse
        }
    }

    It 'records the chosen winget scope, progress bar, and confirms' {
        InModuleScope $script:Module {
            Mock Read-SpectreSelection { 'machine' } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Default install scope (winget)' }
            Mock Read-SpectreSelection { 'retro' } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Winget progress bar style' }
            Mock Read-SpectreConfirm { $true } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Anonymize known paths in winget output?' }
            Mock Read-SpectreConfirm { $true } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Suppress post-install notes?' }

            $s = Invoke-PwshProfileWizard
            $s.WingetScope | Should -Be 'machine'
            $s.WingetProgressBar | Should -Be 'retro'
            $s.WingetAnonymizePath | Should -BeTrue
            $s.WingetDisableInstallNote | Should -BeTrue
        }
    }

    It 'keeps the seeded winget values and skips the per-setting prompts when no changes are requested' {
        InModuleScope $script:Module {
            # Decline the winget change gate; the seeded values (anonymize $true from the mock) must
            # survive rather than being overwritten by the catch-all inner confirm ($false).
            Mock Read-SpectreConfirm { $false } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Change these winget settings?' }

            $s = Invoke-PwshProfileWizard
            $s.WingetScope | Should -Be 'user'
            $s.WingetProgressBar | Should -Be 'rainbow'
            $s.WingetAnonymizePath | Should -BeTrue
            $s.WingetDisableInstallNote | Should -BeFalse
            Should -Invoke Read-SpectreSelection -Times 0 -Exactly -ParameterFilter { $Message -eq 'Default install scope (winget)' }
        }
    }

    It 'leaves the banner shown with theme defaults and skips its prompts when no changes are requested' {
        InModuleScope $script:Module {
            Mock Read-SpectreConfirm { $false } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Change these banner settings?' }

            $s = Invoke-PwshProfileWizard
            $s.Skip | Should -Not -Contain 'Banner'   # still shown
            $s.BannerText | Should -Be '$env:COMPUTERNAME'
            Should -Invoke Read-SpectreConfirm -Times 0 -Exactly -ParameterFilter { $Message -eq 'Show a startup banner?' }
        }
    }
}

Describe 'Read-PwshProfileSettingChange' {
    BeforeEach {
        InModuleScope $script:Module {
            Mock Write-SpectreHost { }
            Mock Read-SpectreConfirm { $true } -RemoveParameterType 'Color'
        }
    }

    It 'returns the confirm result' {
        InModuleScope $script:Module {
            Read-PwshProfileSettingChange -Message 'Change?' | Should -BeTrue
            Mock Read-SpectreConfirm { $false } -RemoveParameterType 'Color'
            Read-PwshProfileSettingChange -Message 'Change?' | Should -BeFalse
        }
    }

    It 'asks the gate with default-No' {
        InModuleScope $script:Module {
            Read-PwshProfileSettingChange -Message 'Change these winget settings?' | Out-Null
            Should -Invoke Read-SpectreConfirm -Times 1 -Exactly -ParameterFilter {
                $Message -eq 'Change these winget settings?' -and $DefaultAnswer -eq 'n'
            }
        }
    }

    It 'flags only the rows whose value differs from the recommendation' {
        InModuleScope $script:Module {
            $rows = @(
                [pscustomobject]@{ Label = 'Default scope'; Value = 'machine'; Recommended = 'user' }
                [pscustomobject]@{ Label = 'Progress bar';  Value = 'rainbow'; Recommended = 'rainbow' }
            )
            Read-PwshProfileSettingChange -Message 'Change?' -Row $rows | Out-Null
            # Differing row carries the "(recommended: …)" note; the matching row does not.
            Should -Invoke Write-SpectreHost -Times 1 -Exactly -ParameterFilter {
                $Message -like '*Default scope*' -and $Message -like '*recommended: user*'
            }
            Should -Invoke Write-SpectreHost -Times 1 -Exactly -ParameterFilter {
                $Message -like '*Progress bar*' -and $Message -notlike '*recommended*'
            }
        }
    }
}

Describe 'Install-PwshProfile' {
    BeforeEach {
        $script:Dir = Join-Path ([System.IO.Path]::GetTempPath()) ('sc-prof-' + [guid]::NewGuid())
        $script:Dest = Join-Path $script:Dir 'profile.ps1'

        Mock -ModuleName $script:Module Write-Figlet { }
        Mock -ModuleName $script:Module Format-SpectrePanel { } -RemoveParameterType 'Color'
        Mock -ModuleName $script:Module Write-SpectreHost { }
        Mock -ModuleName $script:Module Show-NerdFontSetup { }
        Mock -ModuleName $script:Module Invoke-PwshProfileWizard {
            @{
                BannerText = 'Screw City'; BannerColor = '#c9aaff'; BannerAlignment = 'Left'
                BannerFont = 'ANSIShadow'; StepIcon = ':nut_and_bolt:'; ZoxideCommand = 'cd'
                Skip = @(); SkipSection = @(); NerdFont = $null
            }
        }
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:Dir) { Remove-Item -LiteralPath $script:Dir -Recurse -Force }
    }

    It 'writes the bootstrap and returns a Created result with -PassThru' {
        $r = Install-PwshProfile -Path $script:Dest -PassThru
        Test-Path -LiteralPath $script:Dest | Should -BeTrue
        $r.Action | Should -Be 'Created'
        $r.Changed | Should -BeTrue
    }

    It 'returns nothing by default' {
        Install-PwshProfile -Path $script:Dest | Should -BeNullOrEmpty
    }

    It 'reports AlreadyPresent with no change on a no-op re-run' {
        Install-PwshProfile -Path $script:Dest | Out-Null
        $r = Install-PwshProfile -Path $script:Dest -PassThru
        $r.Action | Should -Be 'AlreadyPresent'
        $r.Changed | Should -BeFalse
    }

    It 'reports BareImportPresent over a hand-written import without -Force' {
        New-Item -ItemType Directory -Path $script:Dir | Out-Null
        Set-Content -LiteralPath $script:Dest -Value 'Import-Module ScrewCitySoftware.PwshProfile'
        $r = Install-PwshProfile -Path $script:Dest -PassThru
        $r.Action | Should -Be 'BareImportPresent'
        $r.Changed | Should -BeFalse
        Get-Content -LiteralPath $script:Dest -Raw | Should -Not -Match '# >>>'
    }

    It 'writes nothing when the wizard is cancelled' {
        Mock -ModuleName $script:Module Invoke-PwshProfileWizard { $null }
        $r = Install-PwshProfile -Path $script:Dest -PassThru
        Test-Path -LiteralPath $script:Dest | Should -BeFalse
        $r | Should -BeNullOrEmpty
    }

    It 'installs the chosen Nerd Fonts in one call' -Skip:(-not (Get-Command Install-NerdFont -ErrorAction SilentlyContinue)) {
        Mock -ModuleName $script:Module Invoke-PwshProfileWizard {
            @{
                BannerText = 'Screw City'; BannerColor = '#c9aaff'; BannerAlignment = 'Left'
                BannerFont = 'ANSIShadow'; StepIcon = ':nut_and_bolt:'; ZoxideCommand = 'cd'
                Skip = @(); SkipSection = @(); NerdFont = @('Meslo', 'CascadiaCode')
            }
        }
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Mock -ModuleName $script:Module Import-ModuleSafe { }
        Mock -ModuleName $script:Module Install-NerdFont { }

        Install-PwshProfile -Path $script:Dest | Out-Null
        Should -Invoke -ModuleName $script:Module Install-NerdFont -Times 1 -Exactly `
            -ParameterFilter { $Name -contains 'Meslo' -and $Name -contains 'CascadiaCode' -and $Scope -eq 'CurrentUser' -and $Variant -eq 'Standard' }
        # And shows the terminal-setup panel naming the installed fonts.
        Should -Invoke -ModuleName $script:Module Show-NerdFontSetup -Times 1 -Exactly `
            -ParameterFilter { $Font -contains 'Meslo' -and $Font -contains 'CascadiaCode' }
    }

    It 'does not install fonts under -WhatIf' -Skip:(-not (Get-Command Install-NerdFont -ErrorAction SilentlyContinue)) {
        Mock -ModuleName $script:Module Invoke-PwshProfileWizard {
            @{
                BannerText = 'Screw City'; BannerColor = '#c9aaff'; BannerAlignment = 'Left'
                BannerFont = 'ANSIShadow'; StepIcon = ':nut_and_bolt:'; ZoxideCommand = 'cd'
                Skip = @(); SkipSection = @(); NerdFont = @('Meslo')
            }
        }
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Mock -ModuleName $script:Module Import-ModuleSafe { }
        Mock -ModuleName $script:Module Install-NerdFont { }

        Install-PwshProfile -Path $script:Dest -WhatIf | Out-Null
        Should -Invoke -ModuleName $script:Module Install-NerdFont -Times 0 -Exactly
        Test-Path -LiteralPath $script:Dest | Should -BeFalse
        # The font-setup panel is display-only, so it still shows during a -WhatIf preview.
        Should -Invoke -ModuleName $script:Module Show-NerdFontSetup -Times 1 -Exactly `
            -ParameterFilter { $Font -contains 'Meslo' }
    }

    It 'applies the wizard winget settings via Set-WingetSetting' {
        Mock -ModuleName $script:Module Invoke-PwshProfileWizard {
            @{
                BannerText = 'Screw City'; BannerColor = '#c9aaff'; BannerAlignment = 'Left'
                BannerFont = 'ANSIShadow'; StepIcon = ':nut_and_bolt:'; ZoxideCommand = 'cd'
                Skip = @(); SkipSection = @(); NerdFont = $null
                WingetScope = 'user'; WingetProgressBar = 'retro'
                WingetAnonymizePath = $true; WingetDisableInstallNote = $false
            }
        }
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Mock -ModuleName $script:Module Set-WingetSetting { }

        Install-PwshProfile -Path $script:Dest | Out-Null
        Should -Invoke -ModuleName $script:Module Set-WingetSetting -Times 1 -Exactly `
            -ParameterFilter { $Scope -eq 'user' -and $ProgressBar -eq 'retro' -and $AnonymizePath -eq $true -and $DisableInstallNote -eq $false }
        # The install-time step is marked with a gear, independent of the chosen runtime step icon.
        Should -Invoke -ModuleName $script:Module Invoke-Step -Times 1 -Exactly `
            -ParameterFilter { $Description -eq 'Winget settings' -and $Icon -eq ':gear:' }
    }

    It 'does not touch winget settings under -WhatIf' {
        Mock -ModuleName $script:Module Invoke-PwshProfileWizard {
            @{
                BannerText = 'Screw City'; BannerColor = '#c9aaff'; BannerAlignment = 'Left'
                BannerFont = 'ANSIShadow'; StepIcon = ':nut_and_bolt:'; ZoxideCommand = 'cd'
                Skip = @(); SkipSection = @(); NerdFont = $null
                WingetScope = 'user'; WingetProgressBar = 'rainbow'
                WingetAnonymizePath = $true; WingetDisableInstallNote = $false
            }
        }
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Mock -ModuleName $script:Module Set-WingetSetting { }

        Install-PwshProfile -Path $script:Dest -WhatIf | Out-Null
        Should -Invoke -ModuleName $script:Module Set-WingetSetting -Times 0 -Exactly
    }
}
