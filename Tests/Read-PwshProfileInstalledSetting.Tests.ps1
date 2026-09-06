#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
    $script:Dest = Join-Path ([System.IO.Path]::GetTempPath()) "sc-installed-$([guid]::NewGuid()).ps1"

    # Write a generated bootstrap for the given settings-mutator, then return the parsed result.
    function script:ParseBuilt {
        param([scriptblock]$Mutate, $Argument)
        & (Get-Module $script:Module) {
            param($dest, $mutate, $argument)
            $s = Get-PwshProfileDefault
            & $mutate $s $argument
            $block = Get-PwshProfileBlock -InitializeCall (Build-PwshProfileInitializeCall -Setting $s)
            Set-Content -LiteralPath $dest -Value $block -Encoding utf8 -NoNewline
            Read-PwshProfileInstalledSetting -Path $dest
        } $script:Dest $Mutate $Argument
    }

    # A non-default value for every settings key, so nothing is legitimately omitted from the
    # generated call. Two keys cannot share this shape and are covered by their own cases below:
    # CustomTheme is mutually exclusive with Theme, and NoBanner deliberately suppresses the banner
    # keys.
    $script:NonDefault = [ordered]@{
        Theme             = 'forestcity'
        BannerText        = 'ROUNDTRIP'
        BannerColor       = '#123456'
        BannerAlignment   = 'Center'
        BannerFont        = 'Small'
        StepIcon          = ':rocket:'
        ZoxideCommand     = 'z'
        BatTheme          = 'Nord'
        BatStyle          = 'full'
        LessOptions       = '-R'
        ReplaceCat        = $true
        SetPager          = $true
        ReplaceMore       = $true
        ReplaceHttp       = $true
        FzfGitKeyBindings = $true
        FzfTabChord       = 'Ctrl+j'
    }
    $script:CoveredSeparately = 'CustomTheme', 'NoBanner'
}

Describe 'Read-PwshProfileInstalledSetting' {
    AfterEach {
        Remove-Item -LiteralPath $script:Dest -ErrorAction SilentlyContinue
    }

    It 'round-trips a generated block back into settings' {
        $parsed = script:ParseBuilt {
            param($s)
            $s.Theme = 'forestcity'; $s.ReplaceCat = $true; $s.NoBanner = $true
        }
        $parsed | Should -Not -BeNullOrEmpty
        $parsed.Settings.Theme | Should -Be 'forestcity'
        $parsed.Settings.NoBanner | Should -BeTrue
        $parsed.Settings.ReplaceCat | Should -BeTrue
    }

    It 'round-trips fzf keybinding tuning (a bare -FzfGitKeyBindings and a custom -FzfTabChord)' {
        $parsed = script:ParseBuilt {
            param($s)
            $s.FzfGitKeyBindings = $true; $s.FzfTabChord = 'Ctrl+j'
        }
        # The bare opt-in flag must parse back to $true.
        $parsed.Settings.FzfGitKeyBindings | Should -BeTrue
        $parsed.Settings.FzfTabChord | Should -Be 'Ctrl+j'
    }

    It 'omits the fzf keybinding keys when left at defaults (git chords off)' {
        $parsed = script:ParseBuilt { param($s) $s.FzfTabChord = $s.FzfTabChord }
        $parsed.Settings.ContainsKey('FzfGitKeyBindings') | Should -BeFalse
        $parsed.Settings.ContainsKey('FzfTabChord') | Should -BeFalse
    }

    It 'reads a bare Initialize-PwshProfile call as a successful, empty result' {
        # An install that customized nothing emits no parameters at all. That is a genuine read, not a
        # failure -- and it is why the return keeps its @{ Settings = ... } wrapper: a bare hashtable
        # would be falsy here and the caller's `if ($prior)` would treat it as unparseable.
        $parsed = script:ParseBuilt { param($s) }
        $parsed | Should -Not -BeNullOrEmpty
        @($parsed.Settings.Keys).Count | Should -Be 0
    }


    It 'exercises every key Get-PwshProfileDefault produces' {
        # The guard that makes the round-trip below meaningful. A setting is only safe from being
        # silently dropped if this file knows about it, so adding a key to Get-PwshProfileDefault
        # without adding it here fails right at this assertion -- which is the point.
        #
        # The wizard-settable set is now one list -- Get-PwshProfileSettingSchema -Wizard -- that the
        # defaults, the parser, the call builder and the wizard all project from, so they can no
        # longer disagree. What this suite still guards is the schema itself: a row added there
        # reaches every consumer at once, and only a round-trip proves the new key actually survives
        # Build -> Read rather than merely appearing in all four projections.
        $actual = @(& (Get-Module $script:Module) { @((Get-PwshProfileDefault).Keys) }) | Sort-Object
        $known = @(@($script:NonDefault.Keys) + $script:CoveredSeparately) | Sort-Object
        $actual | Should -Be $known
    }

    It 'preserves every non-default setting through Build -> Read' {
        # The invariant a user actually depends on: re-running the installer must not quietly lose a
        # setting they had. This is the shape that caught BannerFontPath, which Read parsed but
        # nothing downstream consumed or re-emitted.
        $parsed = script:ParseBuilt {
            param($s, $values)
            foreach ($key in $values.Keys) { $s[$key] = $values[$key] }
        } $script:NonDefault

        $parsed | Should -Not -BeNullOrEmpty
        foreach ($key in $script:NonDefault.Keys) {
            $expected = $script:NonDefault[$key]
            $parsed.Settings.ContainsKey($key) |
                Should -BeTrue -Because "'$key' was set to a non-default value, so the generated call should carry it"
            if ($expected -is [array]) {
                @($parsed.Settings[$key]) | Should -Be @($expected) -Because "'$key' should survive the round-trip"
            }
            else {
                $parsed.Settings[$key] | Should -Be $expected -Because "'$key' should survive the round-trip"
            }
        }
    }

    It 'round-trips a custom theme path (mutually exclusive with -Theme)' {
        $parsed = script:ParseBuilt { param($s) $s.CustomTheme = 'C:\themes\mine.omp.json' }
        $parsed.Settings.CustomTheme | Should -Be 'C:\themes\mine.omp.json'
        # Build emits -CustomTheme instead of -Theme, mirroring Initialize-PwshProfile's parameter sets.
        $parsed.Settings.ContainsKey('Theme') | Should -BeFalse
    }

    It 'round-trips -NoBanner and drops the banner keys it makes moot' {
        $parsed = script:ParseBuilt {
            param($s)
            $s.NoBanner = $true
            $s.BannerText = 'IGNORED'; $s.BannerColor = '#abcdef'
        }
        $parsed.Settings.NoBanner | Should -BeTrue
        foreach ($key in 'BannerText', 'BannerColor', 'BannerAlignment', 'BannerFont') {
            $parsed.Settings.ContainsKey($key) |
                Should -BeFalse -Because "-NoBanner makes '$key' moot, so it should not be emitted"
        }
    }

    It 'omits keys left at their defaults, so the generated call stays short' {
        # The flip side of the round-trip: Build only emits what differs from the themed default, and
        # the wizard seeds from those defaults before overlaying what it parsed. An absent key means
        # "keep the default", not "lost".
        $parsed = script:ParseBuilt { param($s) $s.ZoxideCommand = 'z' }
        foreach ($key in 'BannerText', 'BannerColor', 'BannerAlignment', 'BannerFont', 'StepIcon', 'BatTheme') {
            $parsed.Settings.ContainsKey($key) |
                Should -BeFalse -Because "'$key' was left at its default and should not be emitted"
        }
    }
    It 'returns $null when the file has no managed block' {
        Set-Content -LiteralPath $script:Dest -Value "Write-Host 'hi'" -Encoding utf8
        $parsed = & (Get-Module $script:Module) { param($d) Read-PwshProfileInstalledSetting -Path $d } $script:Dest
        $parsed | Should -BeNullOrEmpty
    }

    It 'returns $null for a missing file (no throw)' {
        $parsed = & (Get-Module $script:Module) { Read-PwshProfileInstalledSetting -Path 'X:\does\not\exist.ps1' }
        $parsed | Should -BeNullOrEmpty
    }
}
