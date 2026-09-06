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
    It 'emits a bare call when nothing differs from the defaults' {
        # Every tool runs, so there is no tool pin to emit and a default install carries no arguments
        # at all. Guards the join: interpolating an empty part list would leave a trailing space.
        InModuleScope $script:Module {
            $call = Build-PwshProfileInitializeCall -Setting (Get-PwshProfileDefault)
            $call | Should -Be 'Initialize-PwshProfile'
            $call | Should -Not -Match '\s$'
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
            $s.BannerColor = '#00d7ff'     # a non-default dimension
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

    It 'ignores stray keys a caller left in the settings hashtable' {
        # Build projects from the schema, so a key that is not a settable parameter (a leftover from
        # an older profile, say) is simply not emitted rather than rendered as a bogus argument.
        InModuleScope $script:Module {
            $s = Get-PwshProfileDefault
            $s.Enable = @('Zoxide', 'Bat')
            $s.EnableAll = $true
            Build-PwshProfileInitializeCall -Setting $s | Should -Be 'Initialize-PwshProfile'
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

    It 'emits -NoBanner and omits the banner params under it' {
        InModuleScope $script:Module {
            $s = Get-PwshProfileDefault
            $s.NoBanner = $true
            $s.BannerColor = '#00d7ff'   # would be emitted, but is moot under -NoBanner
            Build-PwshProfileInitializeCall -Setting $s |
                Should -Be 'Initialize-PwshProfile -NoBanner'
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

    It 'emits -ReplaceCat when opted in' {
        InModuleScope $script:Module {
            $s = Get-PwshProfileDefault
            $s.ReplaceCat = $true
            Build-PwshProfileInitializeCall -Setting $s |
                Should -Be 'Initialize-PwshProfile -ReplaceCat'
        }
    }

    It 'emits -ReplaceMore when opted in' {
        InModuleScope $script:Module {
            $s = Get-PwshProfileDefault
            $s.ReplaceMore = $true
            Build-PwshProfileInitializeCall -Setting $s |
                Should -Be 'Initialize-PwshProfile -ReplaceMore'
        }
    }

    It 'omits -ReplaceCat at its default (off)' {
        InModuleScope $script:Module {
            $s = Get-PwshProfileDefault
            $s.ReplaceCat = $false
            $s.BannerColor = '#00d7ff'
            Build-PwshProfileInitializeCall -Setting $s |
                Should -Be "Initialize-PwshProfile -BannerColor '#00d7ff'"
        }
    }

    It 'does not emit the default bat theme/style' {
        InModuleScope $script:Module {
            Build-PwshProfileInitializeCall -Setting (Get-PwshProfileDefault -Theme forestcity) |
                Should -Be 'Initialize-PwshProfile -Theme forestcity'
        }
    }

    It 'emits a non-default -BatTheme and -BatStyle' {
        InModuleScope $script:Module {
            $s = Get-PwshProfileDefault
            $s.BatTheme = 'Nord'
            $s.BatStyle = 'plain'
            Build-PwshProfileInitializeCall -Setting $s |
                Should -Be "Initialize-PwshProfile -BatTheme 'Nord' -BatStyle 'plain'"
        }
    }

    It 'emits a bare -FzfGitKeyBindings only when turned on' {
        InModuleScope $script:Module {
            $s = Get-PwshProfileDefault
            $s.FzfGitKeyBindings = $true
            Build-PwshProfileInitializeCall -Setting $s |
                Should -Be 'Initialize-PwshProfile -FzfGitKeyBindings'
        }
    }

    It 'omits -FzfGitKeyBindings at its default (off)' {
        InModuleScope $script:Module {
            $s = Get-PwshProfileDefault
            Build-PwshProfileInitializeCall -Setting $s |
                Should -Be 'Initialize-PwshProfile'
        }
    }

    It 'emits a non-default -FzfTabChord, single-quoted' {
        InModuleScope $script:Module {
            $s = Get-PwshProfileDefault
            $s.FzfTabChord = 'Ctrl+j'
            Build-PwshProfileInitializeCall -Setting $s |
                Should -Be "Initialize-PwshProfile -FzfTabChord 'Ctrl+j'"
        }
    }

    It 'omits -FzfTabChord at its default (Ctrl+Spacebar)' {
        InModuleScope $script:Module {
            $s = Get-PwshProfileDefault
            $s.FzfTabChord = 'Ctrl+Spacebar'
            Build-PwshProfileInitializeCall -Setting $s |
                Should -Be 'Initialize-PwshProfile'
        }
    }

    Context 'emit order (characterization)' {
        # The ~25 cases above each set one or two keys, so they pin quoting and gating but NOT the
        # order parameters appear in. These four lock every cross-category ordering relationship:
        # scalars in schema order, then switches, then the tool selection last; -NoBanner ahead of the
        # scalars it suppresses; -CustomTheme occupying -Theme's slot. Captured from the live module,
        # so they are a record of current behaviour rather than a judgement about it.
        #
        # Without these, a refactor that derives these lists from a shared source can reorder the
        # generated call and every other test still passes -- the user would only notice as a churning
        # diff in their $PROFILE on each re-run.
        BeforeAll {
            function script:NonDefaultSetting {
                InModuleScope $script:Module {
                    $s = Get-PwshProfileDefault
                    $s.Theme = 'forestcity'
                    $s.BannerText = 'ROUNDTRIP'
                    $s.BannerColor = '#123456'
                    $s.BannerAlignment = 'Center'
                    $s.BannerFont = 'Small'
                    $s.StepIcon = ':rocket:'
                    $s.ZoxideCommand = 'z'
                    $s.BatTheme = 'Nord'
                    $s.BatStyle = 'full'
                    $s.LessOptions = '-R'
                    $s.ReplaceCat = $true
                    $s.SetPager = $true
                    $s.ReplaceMore = $true
                    $s.ReplaceHttp = $true
                    $s.FzfGitKeyBindings = $true
                    $s.FzfTabChord = 'Ctrl+j'
                    $s
                }
            }
        }

        It 'emits every non-default setting in a fixed order' {
            $s = script:NonDefaultSetting
            InModuleScope $script:Module -Parameters @{ S = $s } {
                param($S)
                Build-PwshProfileInitializeCall -Setting $S | Should -Be (
                    "Initialize-PwshProfile -Theme forestcity -BannerText `"ROUNDTRIP`" " +
                    "-BannerColor '#123456' -BannerAlignment 'Center' -BannerFont 'Small' " +
                    "-StepIcon ':rocket:' -ZoxideCommand 'z' -BatTheme 'Nord' -BatStyle 'full' " +
                    "-LessOptions '-R' " +
                    "-FzfTabChord 'Ctrl+j' -ReplaceCat -SetPager -ReplaceMore -ReplaceHttp -FzfGitKeyBindings")
            }
        }

        It 'puts -NoBanner ahead of the scalars and drops the four banner keys' {
            $s = script:NonDefaultSetting
            $s.NoBanner = $true
            InModuleScope $script:Module -Parameters @{ S = $s } {
                param($S)
                Build-PwshProfileInitializeCall -Setting $S | Should -Be (
                    "Initialize-PwshProfile -Theme forestcity -NoBanner " +
                    "-StepIcon ':rocket:' -ZoxideCommand 'z' -BatTheme 'Nord' -BatStyle 'full' " +
                    "-LessOptions '-R' " +
                    "-FzfTabChord 'Ctrl+j' -ReplaceCat -SetPager -ReplaceMore -ReplaceHttp -FzfGitKeyBindings")
            }
        }

        It 'puts -CustomTheme in -Theme''s slot, leaving the rest of the order intact' {
            $s = script:NonDefaultSetting
            $s.CustomTheme = 'C:\themes\mine.omp.json'
            InModuleScope $script:Module -Parameters @{ S = $s } {
                param($S)
                Build-PwshProfileInitializeCall -Setting $S | Should -Be (
                    "Initialize-PwshProfile -CustomTheme 'C:\themes\mine.omp.json' " +
                    "-BannerText `"ROUNDTRIP`" -BannerColor '#123456' -BannerAlignment 'Center' " +
                    "-BannerFont 'Small' -StepIcon ':rocket:' -ZoxideCommand 'z' -BatTheme 'Nord' " +
                    "-BatStyle 'full' -LessOptions '-R' -FzfTabChord 'Ctrl+j' " +
                    "-ReplaceCat -SetPager -ReplaceMore -ReplaceHttp -FzfGitKeyBindings")
            }
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

    It 'writes both markers and the call (no Import-Module)' {
        Invoke-Writer -Path $script:Dest | Out-Null
        $c = Get-Content -LiteralPath $script:Dest -Raw
        $c | Should -Match '# >>> ScrewCitySoftware\.PwshProfile bootstrap >>>'
        $c | Should -Match '# <<< ScrewCitySoftware\.PwshProfile bootstrap <<<'

        $c | Should -Match 'Initialize-PwshProfile'
        $c | Should -Not -Match 'Import-Module ScrewCitySoftware\.PwshProfile'
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
        $r2 = Invoke-Writer -Path $script:Dest -Call 'Initialize-PwshProfile -Enable Xh'
        $c = Get-Content -LiteralPath $script:Dest -Raw
        ([regex]::Matches($c, '# >>> ScrewCitySoftware\.PwshProfile bootstrap >>>')).Count | Should -Be 1
        $c | Should -Match 'Initialize-PwshProfile -Enable Xh'
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
            # The wiring tree drives a real Spectre MultiSelectionPrompt, which throws outside an
            # interactive terminal. Default it to "every box left as seeded", i.e. the incoming value
            # for each row; tests that care about a specific toggle re-mock it.
            Mock Read-PwshProfileWiringTree {
                $out = @{}
                foreach ($row in Get-PwshProfileWiringCatalog) {
                    $out[$row.Setting] = if ($Setting.ContainsKey($row.Setting) -and $Setting[$row.Setting] -eq $row.On) { $row.On } else { $row.Off }
                }
                $out
            } -RemoveParameterType 'Color'
            # Open both "make changes?" gates so the per-setting prompts below run; the gate-closed
            # paths get their own tests.
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
            # Features: pick-specific mode by default, with the tree returning everything enabled.
            # Hub: submit (the first choice).
            Mock Read-SpectreSelection { $Choices[0] } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'What would you like to do?' }
        }
    }

    It 'returns the screwcity defaults when every prompt is left alone' {
        InModuleScope $script:Module {
            $s = Invoke-PwshProfileWizard
            $s.BannerText | Should -Be '$env:COMPUTERNAME'
            $s.BannerColor | Should -Be '#4c81c8'
            $s.StepIcon | Should -Be ':nut_and_bolt:'
            $s.NoBanner | Should -BeFalse
            $s.NerdFont | Should -BeNullOrEmpty
        }
    }

    It 'records the selection-prompt answers alongside the tool options' {
        InModuleScope $script:Module {
            Mock Read-SpectreSelection { 'Center' } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Banner alignment' }
            Mock Read-SpectreSelection { [pscustomobject]@{ Label = 'x'; Icon = ':gear:' } } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Step marker icon' }

            $s = Invoke-PwshProfileWizard
            $s.StepIcon | Should -Be ':gear:'
            $s.BannerAlignment | Should -Be 'Center'
            $s.ZoxideCommand | Should -Be 'cd'
        }
    }

    It 'returns no tool-selection keys at all' {
        # Tool selection is gone: the wizard must not resurrect Enable/EnableAll, or Build would start
        # emitting a pin again and Read would have nothing to parse it back with.
        InModuleScope $script:Module {
            $s = Invoke-PwshProfileWizard
            $s.ContainsKey('Enable') | Should -BeFalse
            $s.ContainsKey('EnableAll') | Should -BeFalse
        }
    }


    It 'carries every prior setting through the re-seed' {
        # Guards the -PriorSetting re-seed list, now a projection of the settings schema: a projection
        # that quietly dropped a key would otherwise go unnoticed. All three reach a prompt pre-filled
        # with the seeded value and the catch-all Read-SpectreText mock returns that default, so the
        # values coming back unchanged is the re-seed working end to end.
        InModuleScope $script:Module {
            $prior = @{ BatTheme = 'Nord'; BatStyle = 'full'; ZoxideCommand = 'z' }
            $s = Invoke-PwshProfileWizard -PriorSetting $prior
            $s.BatTheme | Should -Be 'Nord'
            $s.BatStyle | Should -Be 'full'
            $s.ZoxideCommand | Should -Be 'z'
        }
    }
    It 'folds every checked wiring row back into the settings' {
        InModuleScope $script:Module {
            # The tree answers with the On value for every row, as though the user checked them all.
            Mock Read-PwshProfileWiringTree {
                $out = @{}
                foreach ($row in Get-PwshProfileWiringCatalog) { $out[$row.Setting] = $row.On }
                $out
            } -RemoveParameterType 'Color'

            $s = Invoke-PwshProfileWizard
            $s.ReplaceCat | Should -BeTrue
            $s.SetPager | Should -BeTrue
            $s.ReplaceMore | Should -BeTrue
            $s.ReplaceHttp | Should -BeTrue
            $s.FzfGitKeyBindings | Should -BeTrue
            # ZoxideCommand is the non-boolean row: checked means 'cd', not $true.
            $s.ZoxideCommand | Should -Be 'cd'
        }
    }

    It 'records an unchecked wiring row as a real no, not a missing key' {
        InModuleScope $script:Module {
            Mock Read-PwshProfileWiringTree {
                $out = @{}
                foreach ($row in Get-PwshProfileWiringCatalog) { $out[$row.Setting] = $row.Off }
                $out
            } -RemoveParameterType 'Color'

            # Seed a prior run that had everything on, to prove unchecking actually clears it rather
            # than leaving last time's value in place.
            $s = Invoke-PwshProfileWizard -PriorSetting @{
                ReplaceCat = $true; SetPager = $true; ReplaceMore = $true
                ReplaceHttp = $true; FzfGitKeyBindings = $true; ZoxideCommand = 'cd'
            }
            $s.ReplaceCat | Should -BeFalse
            $s.SetPager | Should -BeFalse
            $s.ReplaceMore | Should -BeFalse
            $s.ReplaceHttp | Should -BeFalse
            $s.FzfGitKeyBindings | Should -BeFalse
            $s.ZoxideCommand | Should -Be 'z'
        }
    }

    It 'seeds the tree from the prior run so a re-run opens pre-checked' {
        InModuleScope $script:Module {
            $s = Invoke-PwshProfileWizard -PriorSetting @{ ReplaceCat = $true; ZoxideCommand = 'z' }
            Should -Invoke Read-PwshProfileWiringTree -Times 1 -Exactly -ParameterFilter {
                $Setting.ReplaceCat -eq $true -and $Setting.ZoxideCommand -eq 'z'
            }
        }
    }

    It 'prompts for the bat theme and style when bat is enabled' {
        InModuleScope $script:Module {
            Mock Read-SpectreText { 'Nord' } -ParameterFilter { $Message -eq 'bat syntax theme' }
            Mock Read-SpectreText { 'full' } -ParameterFilter { $Message -eq 'bat style components' }

            $s = Invoke-PwshProfileWizard
            $s.BatTheme | Should -Be 'Nord'
            $s.BatStyle | Should -Be 'full'
        }
    }

    It 'pre-fills the bat prompts from the selected theme, so Enter keeps the branded values' {
        InModuleScope $script:Module {
            # The catch-all Read-SpectreText mock returns -DefaultAnswer, which is what pressing Enter
            # does. screwcity's branded bat theme is Dracula; BatStyle has a static default.
            $s = Invoke-PwshProfileWizard
            $s.BatTheme | Should -Be 'Dracula'
            $s.BatStyle | Should -Be 'numbers,changes,header'
        }
    }

    It 'prompts for the less options, pre-filled from the default' {
        InModuleScope $script:Module {
            $s = Invoke-PwshProfileWizard
            $s.LessOptions | Should -Be '-R -F -i'
        }
    }

    It 'captures custom less options' {
        InModuleScope $script:Module {
            Mock Read-SpectreText { '-R' } -ParameterFilter { $Message -eq 'less options ($env:LESS)' }
            $s = Invoke-PwshProfileWizard
            $s.LessOptions | Should -Be '-R'
        }
    }

    It 'leaves the wiring toggles off by default, with the default tab chord' {
        InModuleScope $script:Module {
            # BeforeEach's tree mock echoes the seed, and a clean run seeds every toggle off.
            $s = Invoke-PwshProfileWizard
            $s.FzfGitKeyBindings | Should -BeFalse
            $s.ReplaceCat | Should -BeFalse
            $s.FzfTabChord | Should -Be 'Ctrl+Spacebar'
        }
    }

    It 'captures a custom fzf tab chord' {
        InModuleScope $script:Module {
            Mock Read-SpectreText { 'Ctrl+j' } -ParameterFilter { $Message -eq 'PSFzf tab-completion picker chord' }

            $s = Invoke-PwshProfileWizard
            $s.FzfTabChord | Should -Be 'Ctrl+j'
        }
    }

    It 'sets NoBanner and skips the theming sub-steps when the banner is declined' {
        InModuleScope $script:Module {
            Mock Read-SpectreConfirm { $false } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Show a startup banner?' }

            $s = Invoke-PwshProfileWizard
            $s.NoBanner | Should -BeTrue
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
            # The regression this step fixes. BatTheme is branded exactly like the two above, but was
            # left out of the re-seed, so picking forestcity kept Screw City's Dracula and wrote it
            # into the profile as an explicit -BatTheme.
            $s.BatTheme | Should -Be 'gruvbox-dark'
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
                # A custom prompt has no bundled identity to match, so bat follows the terminal's own
                # ANSI palette rather than silently inheriting Screw City's.
                $s.BatTheme | Should -Be 'ansi'
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
            # Format-SpectrePanel emits its rendered string to the pipeline; Write-PwshProfileStepHeader
            # pipes it to Out-Host so it never escapes. Without that Out-Host this sentinel would leak
            # through the bare step calls and the result would be Object[] instead of a hashtable.
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

    It 'records SetTerminalFont = $false when the WT-font prompt is declined' {
        InModuleScope $script:Module {
            # The BeforeEach catch-all Read-SpectreConfirm { $false } declines the WT-font prompt.
            $s = Invoke-PwshProfileWizard
            $s.SetTerminalFont | Should -BeFalse
        }
    }

    It 'records SetTerminalFont = $true when the WT-font prompt is accepted' {
        InModuleScope $script:Module {
            Mock Read-SpectreConfirm { $true } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Set MesloLGM Nerd Font as the Windows Terminal default font?' }
            $s = Invoke-PwshProfileWizard
            $s.SetTerminalFont | Should -BeTrue
        }
    }

    It 'records InstallTerminalScheme/SetSchemeDefault = $false when the scheme prompt is declined' {
        InModuleScope $script:Module {
            # The BeforeEach catch-all Read-SpectreConfirm { $false } declines the install prompt, so the
            # set-default follow-up is never asked.
            $s = Invoke-PwshProfileWizard
            $s.InstallTerminalScheme | Should -BeFalse
            $s.SetSchemeDefault | Should -BeFalse
        }
    }

    It 'records InstallTerminalScheme/SetSchemeDefault = $true when both scheme prompts are accepted' {
        InModuleScope $script:Module {
            Mock Read-SpectreConfirm { $true } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Install the matching Windows Terminal color scheme?' }
            Mock Read-SpectreConfirm { $true } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Set it as the Windows Terminal default color scheme?' }
            $s = Invoke-PwshProfileWizard
            $s.InstallTerminalScheme | Should -BeTrue
            $s.SetSchemeDefault | Should -BeTrue
        }
    }

    It 'installs the scheme but leaves it non-default when the set-default follow-up is declined' {
        InModuleScope $script:Module {
            Mock Read-SpectreConfirm { $true } -RemoveParameterType 'Color' -ParameterFilter { $Message -eq 'Install the matching Windows Terminal color scheme?' }
            # The set-default follow-up falls through to the catch-all $false.
            $s = Invoke-PwshProfileWizard
            $s.InstallTerminalScheme | Should -BeTrue
            $s.SetSchemeDefault | Should -BeFalse
        }
    }

    It 'shows the tool inventory in the Winget step, before its change gate' {
        # Ordering is the point: the list frames the winget settings question rather than trailing it
        # -- scope and progress bar matter precisely because that is what they get applied to. It is
        # also the earliest the plan can be seen, since the install runs after the review screen.
        InModuleScope $script:Module {
            $script:WingetOrder = [System.Collections.Generic.List[string]]::new()
            Mock Show-PwshProfileInventory { $script:WingetOrder.Add('inventory') } -RemoveParameterType 'Color'
            Mock Read-PwshProfileSettingChange {
                if ($Message -eq 'Change these winget settings?') { $script:WingetOrder.Add('gate') }
                $false
            } -RemoveParameterType 'Accent'

            $null = Invoke-PwshProfileWizard

            $script:WingetOrder | Should -Contain 'inventory'
            $script:WingetOrder.IndexOf('inventory') | Should -BeLessThan $script:WingetOrder.IndexOf('gate')
        }
    }

    It 'discloses the PowerShell modules in a step of its own' {
        # They install quietly, in the middle of a startup step, so the wizard names them up front.
        # Nothing is asked here, which is why this only checks that the whole catalog is rendered --
        # the step's job is disclosure, not a choice.
        InModuleScope $script:Module {
            $script:ModuleRows = $null
            # The Winget step calls the same renderer with no -Row (it defaults to the tool
            # inventory), so record only the call that passes rows explicitly.
            Mock Show-PwshProfileInventory { if ($Row) { $script:ModuleRows = $Row } } -RemoveParameterType 'Color'

            $null = Invoke-PwshProfileWizard

            @($script:ModuleRows.Name) | Should -Be @((Get-PwshProfileModuleCatalog).Name)
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
            $s.NoBanner | Should -BeFalse   # still shown
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
        # The done step now offers to reload the profile. Mocking the wizard bypassed every prompt
        # until now, so without these two the tests that write a file would hit a real Spectre
        # prompt -- and the function's own interactivity guard would not save them, since it probes
        # whether the MODULE exposes Read-SpectreSelection, not whether the host is interactive.
        Mock -ModuleName $script:Module Read-SpectreConfirm { $false } -RemoveParameterType 'Color'
        Mock -ModuleName $script:Module Invoke-InGlobalScope { }
        # The installer now installs the tool CLIs itself. Stub the shared winget helper so the suite
        # never touches winget -- without this every run would attempt the whole catalog.
        Mock -ModuleName $script:Module Install-WingetPackageSafe { }
        Mock -ModuleName $script:Module Invoke-PwshProfileWizard {
            @{
                BannerText = 'Screw City'; BannerColor = '#c9aaff'; BannerAlignment = 'Left'
                BannerFont = 'ANSIShadow'; StepIcon = ':nut_and_bolt:'; ZoxideCommand = 'cd'
                NoBanner = $false; NerdFont = $null
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
                NoBanner = $false; NerdFont = @('Meslo', 'CascadiaCode')
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
                NoBanner = $false; NerdFont = @('Meslo')
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
                NoBanner = $false; NerdFont = $null
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
                NoBanner = $false; NerdFont = $null
                WingetScope = 'user'; WingetProgressBar = 'rainbow'
                WingetAnonymizePath = $true; WingetDisableInstallNote = $false
            }
        }
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Mock -ModuleName $script:Module Set-WingetSetting { }

        Install-PwshProfile -Path $script:Dest -WhatIf | Out-Null
        Should -Invoke -ModuleName $script:Module Set-WingetSetting -Times 0 -Exactly
    }

    It 'installs quietly, so setup does not trip the startup-installed notice' {
        # Installing IS the expected work here; the notice exists to flag the opposite case.
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Install-PwshProfile -Path $script:Dest | Out-Null
        Should -Invoke -ModuleName $script:Module Install-WingetPackageSafe -Times 0 -Exactly `
            -ParameterFilter { -not $Quiet }
    }

    It 'opens a top-level step per package it actually installs' {
        # The point of the whole arrangement: TOP-LEVEL, so each writes its own permanent line with
        # real elapsed time. Nested, they would only mutate the transient spinner and leave nothing
        # behind -- which is the opaque single line this replaces.
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Mock -ModuleName $script:Module Get-PwshProfileToolInventory {
            @(
                [pscustomobject]@{ Label = 'uv (Python toolchain)'; Token = 'Uv'; PackageId = 'astral-sh.uv'; Exe = 'uv.exe'; PathDir = $null; Scope = $null; Installed = $false }
                [pscustomobject]@{ Label = 'zoxide (smart cd)'; Token = 'Zoxide'; PackageId = 'a.zoxide'; Exe = 'zoxide.exe'; PathDir = $null; Scope = $null; Installed = $true }
            )
        }

        Install-PwshProfile -Path $script:Dest | Out-Null

        Should -Invoke -ModuleName $script:Module Invoke-Step -Times 1 -Exactly `
            -ParameterFilter { $Description -eq 'Installing uv (Python toolchain)' -and $Icon -eq ':gear:' }
        Should -Invoke -ModuleName $script:Module Install-WingetPackageSafe -Times 1 -Exactly `
            -ParameterFilter { $Id -eq 'astral-sh.uv' -and $Exe -eq 'uv.exe' }
    }

    It 'forwards the install location for a package that has one of its own' {
        # git and oh-my-posh are full installers, not winget portables. Without their PathDir the
        # package would install correctly and the shared portable Links dir would go on PATH instead,
        # leaving the post-install re-check to warn about an install that had in fact worked.
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Mock -ModuleName $script:Module Get-PwshProfileToolInventory {
            @(
                [pscustomobject]@{ Label = 'git (version control)'; Token = 'Git'; PackageId = 'Git.Git'; Exe = 'git.exe'; PathDir = 'C:\Program Files\Git\cmd'; Scope = $null; Installed = $false }
                [pscustomobject]@{ Label = 'oh-my-posh (prompt)'; Token = 'OhMyPosh'; PackageId = 'JanDeDobbeleer.OhMyPosh'; Exe = 'oh-my-posh.exe'; PathDir = 'C:\omp\bin'; Scope = 'user'; Installed = $false }
                [pscustomobject]@{ Label = 'uv (Python toolchain)'; Token = 'Uv'; PackageId = 'astral-sh.uv'; Exe = 'uv.exe'; PathDir = $null; Scope = $null; Installed = $false }
            )
        }

        Install-PwshProfile -Path $script:Dest | Out-Null

        Should -Invoke -ModuleName $script:Module Install-WingetPackageSafe -Times 1 -Exactly `
            -ParameterFilter { $Id -eq 'Git.Git' -and $PathDir -eq 'C:\Program Files\Git\cmd' -and -not $Scope }
        Should -Invoke -ModuleName $script:Module Install-WingetPackageSafe -Times 1 -Exactly `
            -ParameterFilter { $Id -eq 'JanDeDobbeleer.OhMyPosh' -and $PathDir -eq 'C:\omp\bin' -and $Scope -eq 'user' }
        # A portable passes neither, so Install-WingetPackageSafe applies its shared-Links default.
        Should -Invoke -ModuleName $script:Module Install-WingetPackageSafe -Times 1 -Exactly `
            -ParameterFilter { $Id -eq 'astral-sh.uv' -and -not $PathDir -and -not $Scope }
    }

    It 'gives an already-present tool no line and no install call' {
        # Nine `[ 3ms]` lines for tools that were already there would be noise, and the helper would
        # short-circuit on Get-Command anyway.
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Mock -ModuleName $script:Module Get-PwshProfileToolInventory {
            @(
                [pscustomobject]@{ Label = 'uv (Python toolchain)'; Token = 'Uv'; PackageId = 'astral-sh.uv'; Exe = 'uv.exe'; PathDir = $null; Scope = $null; Installed = $false }
                [pscustomobject]@{ Label = 'zoxide (smart cd)'; Token = 'Zoxide'; PackageId = 'a.zoxide'; Exe = 'zoxide.exe'; PathDir = $null; Scope = $null; Installed = $true }
            )
        }

        Install-PwshProfile -Path $script:Dest | Out-Null

        Should -Invoke -ModuleName $script:Module Invoke-Step -Times 0 -Exactly `
            -ParameterFilter { $Description -like '*zoxide*' }
        Should -Invoke -ModuleName $script:Module Install-WingetPackageSafe -Times 0 -Exactly `
            -ParameterFilter { $Id -eq 'a.zoxide' }
    }

    It 'renders one reassuring line when every tool is already present' {
        # Silence would read as "did it skip the tools?". The body re-runs the short-circuit for all
        # of them, so the line carries a real elapsed time rather than 0ms.
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Mock -ModuleName $script:Module Get-PwshProfileToolInventory {
            @(
                [pscustomobject]@{ Label = 'uv (Python toolchain)'; Token = 'Uv'; PackageId = 'astral-sh.uv'; Exe = 'uv.exe'; PathDir = $null; Scope = $null; Installed = $true }
                [pscustomobject]@{ Label = 'zoxide (smart cd)'; Token = 'Zoxide'; PackageId = 'a.zoxide'; Exe = 'zoxide.exe'; PathDir = $null; Scope = $null; Installed = $true }
            )
        }

        Install-PwshProfile -Path $script:Dest | Out-Null

        Should -Invoke -ModuleName $script:Module Invoke-Step -Times 1 -Exactly `
            -ParameterFilter { $Description -eq 'Tools — all 2 already present' -and $Icon -eq ':gear:' }
        Should -Invoke -ModuleName $script:Module Invoke-Step -Times 0 -Exactly `
            -ParameterFilter { $Description -like 'Installing *' }
        # Still verified, so a tool that vanished since the probe is caught.
        Should -Invoke -ModuleName $script:Module Install-WingetPackageSafe -Times 2 -Exactly
    }

    It 'installs no tools under -WhatIf' {
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Install-PwshProfile -Path $script:Dest -WhatIf | Out-Null
        Should -Invoke -ModuleName $script:Module Install-WingetPackageSafe -Times 0 -Exactly
    }

    It 'offers to reload the profile once the bootstrap is written' {
        Install-PwshProfile -Path $script:Dest | Out-Null
        Should -Invoke -ModuleName $script:Module Read-SpectreConfirm -Times 1 -Exactly `
            -ParameterFilter { $Message -eq 'Reload your profile now?' }
    }

    It 'dot-sources the written file in global scope when the reload is accepted' {
        # Global scope is the whole point: run from a module function, a bare `. $path` would load
        # into THAT function's scope and every alias and function it defines would vanish on return.
        Mock -ModuleName $script:Module Read-SpectreConfirm { $true } -RemoveParameterType 'Color' `
            -ParameterFilter { $Message -eq 'Reload your profile now?' }

        Install-PwshProfile -Path $script:Dest | Out-Null

        Should -Invoke -ModuleName $script:Module Invoke-InGlobalScope -Times 1 -Exactly `
            -ParameterFilter { $Expression -eq ". '$script:Dest'" }
    }

    It 'quotes the path so one containing a quote cannot break out' {
        $script:Odd = Join-Path $script:Dir "it's here.ps1"
        Mock -ModuleName $script:Module Read-SpectreConfirm { $true } -RemoveParameterType 'Color' `
            -ParameterFilter { $Message -eq 'Reload your profile now?' }

        Install-PwshProfile -Path $script:Odd | Out-Null

        # Single-quoted with the quote doubled, so the path is data rather than script -- and a path
        # holding a $ can't interpolate either.
        Should -Invoke -ModuleName $script:Module Invoke-InGlobalScope -Times 1 -Exactly `
            -ParameterFilter { $Expression -eq ". '$($script:Odd -replace "'", "''")'" }
    }

    It 'reloads nothing when the offer is declined' {
        # The BeforeEach mock answers no.
        Install-PwshProfile -Path $script:Dest | Out-Null
        Should -Invoke -ModuleName $script:Module Invoke-InGlobalScope -Times 0 -Exactly
    }

    It 'does not offer a reload under -WhatIf' {
        # Changed is computed BEFORE ShouldProcess, so it is $true here even though nothing was
        # written -- which is exactly why the gate carries its own -not $WhatIfPreference.
        Install-PwshProfile -Path $script:Dest -WhatIf | Out-Null
        Should -Invoke -ModuleName $script:Module Read-SpectreConfirm -Times 0 -Exactly `
            -ParameterFilter { $Message -eq 'Reload your profile now?' }
    }

    It 'does not offer a reload when nothing changed' {
        # A no-op re-run reports AlreadyPresent; there is nothing new to apply.
        Install-PwshProfile -Path $script:Dest | Out-Null
        Install-PwshProfile -Path $script:Dest | Out-Null
        Should -Invoke -ModuleName $script:Module Read-SpectreConfirm -Times 1 -Exactly `
            -ParameterFilter { $Message -eq 'Reload your profile now?' }
    }

    It 'warns rather than throwing when the reload fails' {
        # Against this command's usual "genuine errors throw" rule, deliberately: the install has
        # already succeeded by this point, and a user's own profile code throwing must not turn a
        # completed install into a failed one.
        Mock -ModuleName $script:Module Read-SpectreConfirm { $true } -RemoveParameterType 'Color' `
            -ParameterFilter { $Message -eq 'Reload your profile now?' }
        Mock -ModuleName $script:Module Invoke-InGlobalScope { throw 'boom' }

        { Install-PwshProfile -Path $script:Dest -WarningAction SilentlyContinue | Out-Null } |
            Should -Not -Throw
    }

    It 'names the file and the failure in that warning' {
        Mock -ModuleName $script:Module Read-SpectreConfirm { $true } -RemoveParameterType 'Color' `
            -ParameterFilter { $Message -eq 'Reload your profile now?' }
        Mock -ModuleName $script:Module Invoke-InGlobalScope { throw 'boom' }

        Install-PwshProfile -Path $script:Dest -WarningVariable w -WarningAction SilentlyContinue | Out-Null

        "$w" | Should -BeLike '*boom*'
        "$w" | Should -BeLike '*Restart your shell*'
    }

    It 'keeps the reload output out of its own pipeline' {
        # Invoke-InGlobalScope returns whatever the dot-sourced script emits. Unsuppressed, a profile
        # that prints anything would leak into this command's output and break "returns nothing
        # without -PassThru" -- so the $null = on that call is load-bearing, not tidiness.
        Mock -ModuleName $script:Module Read-SpectreConfirm { $true } -RemoveParameterType 'Color' `
            -ParameterFilter { $Message -eq 'Reload your profile now?' }
        Mock -ModuleName $script:Module Invoke-InGlobalScope { 'chatty profile output' }

        Install-PwshProfile -Path $script:Dest | Should -BeNullOrEmpty
    }

    It 'installs the tools after the winget settings are applied' {
        # Scope and progress-bar preferences must be in place before installing through winget, so the
        # ordering is load-bearing rather than incidental.
        Mock -ModuleName $script:Module Invoke-PwshProfileWizard {
            @{
                BannerText = 'Screw City'; BannerColor = '#c9aaff'; BannerAlignment = 'Left'
                BannerFont = 'ANSIShadow'; StepIcon = ':nut_and_bolt:'; ZoxideCommand = 'cd'
                NoBanner = $false; NerdFont = $null
                WingetScope = 'user'; WingetProgressBar = 'rainbow'
                WingetAnonymizePath = $true; WingetDisableInstallNote = $false
            }
        }
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        $script:Order = [System.Collections.Generic.List[string]]::new()
        Mock -ModuleName $script:Module Set-WingetSetting { $script:Order.Add('settings') }
        Mock -ModuleName $script:Module Install-WingetPackageSafe { $script:Order.Add('install') }

        Install-PwshProfile -Path $script:Dest | Out-Null

        $script:Order[0] | Should -Be 'settings'
        $script:Order | Should -Contain 'install'
    }

    It 'sets the Windows Terminal font via Set-WindowsTerminalFont when opted in' {
        Mock -ModuleName $script:Module Invoke-PwshProfileWizard {
            @{
                BannerText = 'Screw City'; BannerColor = '#c9aaff'; BannerAlignment = 'Left'
                BannerFont = 'ANSIShadow'; StepIcon = ':nut_and_bolt:'; ZoxideCommand = 'cd'
                NoBanner = $false; NerdFont = $null
                SetTerminalFont = $true
            }
        }
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Mock -ModuleName $script:Module Set-WindowsTerminalFont { }

        Install-PwshProfile -Path $script:Dest | Out-Null
        Should -Invoke -ModuleName $script:Module Set-WindowsTerminalFont -Times 1 -Exactly `
            -ParameterFilter { $FontFace -eq 'MesloLGM Nerd Font' }
        # The install-time step is marked with a gear, independent of the chosen runtime step icon.
        Should -Invoke -ModuleName $script:Module Invoke-Step -Times 1 -Exactly `
            -ParameterFilter { $Description -eq 'Windows Terminal font' -and $Icon -eq ':gear:' }
    }

    It 'does not set the Windows Terminal font when the wizard declined it' {
        Mock -ModuleName $script:Module Invoke-PwshProfileWizard {
            @{
                BannerText = 'Screw City'; BannerColor = '#c9aaff'; BannerAlignment = 'Left'
                BannerFont = 'ANSIShadow'; StepIcon = ':nut_and_bolt:'; ZoxideCommand = 'cd'
                NoBanner = $false; NerdFont = $null
                SetTerminalFont = $false
            }
        }
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Mock -ModuleName $script:Module Set-WindowsTerminalFont { }

        Install-PwshProfile -Path $script:Dest | Out-Null
        Should -Invoke -ModuleName $script:Module Set-WindowsTerminalFont -Times 0 -Exactly
    }

    It 'does not set the Windows Terminal font under -WhatIf' {
        Mock -ModuleName $script:Module Invoke-PwshProfileWizard {
            @{
                BannerText = 'Screw City'; BannerColor = '#c9aaff'; BannerAlignment = 'Left'
                BannerFont = 'ANSIShadow'; StepIcon = ':nut_and_bolt:'; ZoxideCommand = 'cd'
                NoBanner = $false; NerdFont = $null
                SetTerminalFont = $true
            }
        }
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Mock -ModuleName $script:Module Set-WindowsTerminalFont { }

        Install-PwshProfile -Path $script:Dest -WhatIf | Out-Null
        Should -Invoke -ModuleName $script:Module Set-WindowsTerminalFont -Times 0 -Exactly
    }

    It 'installs the matching Windows Terminal scheme (with -SetDefault) when opted in' {
        Mock -ModuleName $script:Module Invoke-PwshProfileWizard {
            @{
                Theme = 'forestcity'; CustomTheme = ''
                BannerText = 'Screw City'; BannerColor = '#c9aaff'; BannerAlignment = 'Left'
                BannerFont = 'ANSIShadow'; StepIcon = ':nut_and_bolt:'; ZoxideCommand = 'cd'
                NoBanner = $false; NerdFont = $null
                InstallTerminalScheme = $true; SetSchemeDefault = $true
            }
        }
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Mock -ModuleName $script:Module Install-WindowsTerminalScheme { }

        Install-PwshProfile -Path $script:Dest | Out-Null
        Should -Invoke -ModuleName $script:Module Install-WindowsTerminalScheme -Times 1 -Exactly `
            -ParameterFilter { $Theme -eq 'forestcity' -and $SetDefault }
        # The install-time step is marked with a gear, independent of the chosen runtime step icon.
        Should -Invoke -ModuleName $script:Module Invoke-Step -Times 1 -Exactly `
            -ParameterFilter { $Description -eq 'Windows Terminal scheme' -and $Icon -eq ':gear:' }
    }

    It 'installs the scheme without -SetDefault when the set-default follow-up was declined' {
        Mock -ModuleName $script:Module Invoke-PwshProfileWizard {
            @{
                Theme = 'screwcity'; CustomTheme = ''
                BannerText = 'Screw City'; BannerColor = '#c9aaff'; BannerAlignment = 'Left'
                BannerFont = 'ANSIShadow'; StepIcon = ':nut_and_bolt:'; ZoxideCommand = 'cd'
                NoBanner = $false; NerdFont = $null
                InstallTerminalScheme = $true; SetSchemeDefault = $false
            }
        }
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Mock -ModuleName $script:Module Install-WindowsTerminalScheme { }

        Install-PwshProfile -Path $script:Dest | Out-Null
        Should -Invoke -ModuleName $script:Module Install-WindowsTerminalScheme -Times 1 -Exactly `
            -ParameterFilter { $Theme -eq 'screwcity' -and -not $SetDefault }
    }

    It 'does not install the scheme when the wizard declined it' {
        Mock -ModuleName $script:Module Invoke-PwshProfileWizard {
            @{
                Theme = 'screwcity'; CustomTheme = ''
                BannerText = 'Screw City'; BannerColor = '#c9aaff'; BannerAlignment = 'Left'
                BannerFont = 'ANSIShadow'; StepIcon = ':nut_and_bolt:'; ZoxideCommand = 'cd'
                NoBanner = $false; NerdFont = $null
                InstallTerminalScheme = $false; SetSchemeDefault = $false
            }
        }
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Mock -ModuleName $script:Module Install-WindowsTerminalScheme { }

        Install-PwshProfile -Path $script:Dest | Out-Null
        Should -Invoke -ModuleName $script:Module Install-WindowsTerminalScheme -Times 0 -Exactly
    }

    It 'does not install the scheme under -WhatIf' {
        Mock -ModuleName $script:Module Invoke-PwshProfileWizard {
            @{
                Theme = 'screwcity'; CustomTheme = ''
                BannerText = 'Screw City'; BannerColor = '#c9aaff'; BannerAlignment = 'Left'
                BannerFont = 'ANSIShadow'; StepIcon = ':nut_and_bolt:'; ZoxideCommand = 'cd'
                NoBanner = $false; NerdFont = $null
                InstallTerminalScheme = $true; SetSchemeDefault = $true
            }
        }
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Mock -ModuleName $script:Module Install-WindowsTerminalScheme { }

        Install-PwshProfile -Path $script:Dest -WhatIf | Out-Null
        Should -Invoke -ModuleName $script:Module Install-WindowsTerminalScheme -Times 0 -Exactly
    }
}
