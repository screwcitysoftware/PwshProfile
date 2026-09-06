function Invoke-PwshProfileWizard {
    <#
    .SYNOPSIS
        Runs the interactive Install-PwshProfile setup wizard and returns the chosen settings (or
        $null if the user cancels).

    .DESCRIPTION
        Drives the PwshSpectreConsole prompts that collect the profile configuration and returns a
        settings hashtable: the keys of Get-PwshProfileDefault, plus NerdFont (the chosen font names,
        or $null), SetTerminalFont, InstallTerminalScheme / SetSchemeDefault, and the four Winget*
        keys. Cancelling at the review screen returns $null and Install-PwshProfile writes nothing.

        Each step opens with a rounded header panel (Write-PwshProfileStepHeader) carrying the title, a
        "N of M" counter, and a description; secondary prompts get inline hint lines
        (Write-PwshProfilePromptHelp). Both run their text through Format-PwshProfileHelpMarkup so tool
        names and code literals are highlighted rather than flat grey. Selection prompts clear
        themselves on submit, unlike text prompts, so each choice is echoed afterward via
        Write-PwshProfilePromptAnswer to keep a visible record.

        One forward pass through the steps, then a review hub where any step can be re-edited before
        submitting, or the whole thing cancelled:

          1. Nerd Fonts (optional): installs the recommended Meslo + CascadiaCode pair, then offers to
             set 'MesloLGM Nerd Font' as the Windows Terminal default font.
          2. Winget: a curated set of winget client settings (install scope, progress bar, anonymize
             paths, suppress install notes), pre-filled from the live settings.json and gated behind a
             single "change these?" prompt that defaults to No.
          3. Theme: a bundled oh-my-posh theme or a custom path. The bundled choice seeds the banner
             color and step icon that later prompts pre-fill from; a custom path seeds neutral ones.
             Re-picking a theme preserves any color/icon already customized. It then offers the
             matching Windows Terminal color scheme, and if accepted, whether to make it the default.
          4. Banner: shows the current config and gates the per-setting prompts behind the same
             "change these?" pattern. Clearing the banner text hides the banner — since BannerText must
             be non-empty, a cleared text becomes -NoBanner rather than a shown-but-blank half-state.
          5. Step icon: always asked, since the icon marks every startup step whether or not there is a
             banner. A curated shortcode menu with the current icon floated to the top, plus a custom
             escape hatch.
          6. Features (opt-in): pick specific tools, or enable everything including future additions.
             "Specific" shows the grouped Core / WinGet tree, pre-checking the prior -Enable set on a
             re-run or the Core default-on set on a clean run, and tagging new tools "(new)". If
             zoxide, bat, less or fzf end up enabled, their tuning prompts follow.

        The font, winget, and terminal-scheme choices are one-time machine actions applied by
        Install-PwshProfile, not baked into the bootstrap call.

        Assumes the Spectre prompt cmdlets are available — Install-PwshProfile guards that and warns
        that an interactive session is required when they are not.

    .PARAMETER PriorSetting
        On a re-run, the settings parsed from the existing block via Read-PwshProfileInstalledSetting,
        used to seed every prompt with last time's choice.

    .PARAMETER NewTool
        Tokens newly available since the prior setup, forwarded to the feature tree so they are tagged
        "(new)" and start unchecked.

    .EXAMPLE
        Invoke-PwshProfileWizard

        Walks the prompts and returns the resulting settings hashtable, or $null if cancelled.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [hashtable]$PriorSetting,

        [Parameter()]
        [string[]]$NewTool = @()
    )

    # Shared mutable state, passed by reference into every step so review-hub edits stick.
    # Settings is returned to the caller; Def is the current theme's baseline (pre-fills and the
    # "still default?" preserve-edits check); Accent/Code are the installer's own UI colors, fixed
    # rather than following the theme being configured.
    # Seed from the prior theme's defaults, then overlay the parsed prior choices so every prompt
    # defaults to last time. On a first run PriorSetting is absent and this is just screwcity.
    $priorTheme = if ($PriorSetting -and $PriorSetting.ContainsKey('Theme') -and $PriorSetting.Theme) { $PriorSetting.Theme } else { 'screwcity' }
    $def = Get-PwshProfileDefault -Theme $priorTheme
    $settings = $def.Clone()
    # Every setting a profile can carry, from the schema — so a parameter cannot be added to the
    # bootstrap and then silently fail to survive a re-run. Deliberately not the install-time keys set
    # just below (NerdFont, the Windows Terminal pair, the winget four): those are one-time machine
    # actions that re-ask every run rather than being remembered.
    if ($PriorSetting) {
        foreach ($k in @((Get-PwshProfileSettingSchema -Wizard).Name)) {
            if ($PriorSetting.ContainsKey($k)) { $settings[$k] = $PriorSetting[$k] }
        }
    }
    $settings.NerdFont = $null
    # Install-time actions, not part of the bootstrap — never re-seeded, so they re-ask every run.
    $settings.SetTerminalFont = $false
    $settings.InstallTerminalScheme = $false
    $settings.SetSchemeDefault = $false
    # winget client settings — applied at install time, not part of the bootstrap. Seeded from the
    # live settings file: an explicit value pre-fills, otherwise the module default.
    $wingetDef = Get-WingetSettingDefault
    $settings.WingetScope = $wingetDef.Scope
    $settings.WingetProgressBar = $wingetDef.ProgressBar
    $settings.WingetAnonymizePath = $wingetDef.AnonymizePath
    $settings.WingetDisableInstallNote = $wingetDef.DisableInstallNote
    $state = @{ Settings = $settings; Def = $def; Accent = '#c9aaff'; Code = '#5fd7ff' }

    # Escape a dynamic value for safe inclusion in Spectre markup (banner text, paths, …).
    function ConvertTo-EscapedText {
        param($Text)
        if ([string]::IsNullOrEmpty("$Text")) { return '' }
        Get-SpectreEscapedTextSafe -Text "$Text"
    }

    # --- Step: Theme ------------------------------------------------------------------------
    $stepTheme = {
        param($s, $i, $total)
        Write-PwshProfileStepHeader -Title 'Theme' -Index $i -Total $total -Accent $s.Accent -Code $s.Code `
            -Body '**oh-my-posh** draws your prompt — its colors, segments, and the layout of each line. Pick a bundled look or point to your own `.omp.json` file.'
        $themeChoices = @(
            @(Get-BundledThemeName) | ForEach-Object {
                $b = Get-BundledThemeBranding -Name $_
                [pscustomobject]@{ Label = "$_  —  $($b.DisplayName)"; Theme = $_; Custom = $false }
            }
            [pscustomobject]@{ Label = 'Custom path…'; Theme = $null; Custom = $true }
        )
        # Float the current theme to the top so Enter keeps it.
        $cur = $s.Settings.Theme
        $themeChoices = @($themeChoices | Where-Object { $_.Theme -eq $cur }) +
                        @($themeChoices | Where-Object { $_.Theme -ne $cur })
        $pickTheme = Read-SpectreSelection -Message 'Choose an oh-my-posh theme' -Color $s.Accent -Choices $themeChoices -ChoiceLabelProperty Label
        Write-PwshProfilePromptAnswer $pickTheme.Label -Accent $s.Accent

        # Branding the current fields were seeded from, so only untouched ones get re-seeded.
        $neutral = @{ BannerColor = 'Silver'; StepIcon = ':gear:' }
        $prevBranding = if ($s.Settings.CustomTheme) { $neutral } else { Get-BundledThemeBranding -Name $s.Settings.Theme }

        if ($pickTheme.Custom) {
            do {
                Write-PwshProfilePromptHelp 'Enter the full path to an **oh-my-posh** theme file (a `.omp.json`) on disk.' -Accent $s.Accent -Code $s.Code
                $customPath = Read-SpectreText -Message 'Path to your custom oh-my-posh theme (.omp.json)'
                $pathOk = $customPath -and (Test-Path -Path $customPath)
                if (-not $pathOk) { Write-Warning "Theme path '$customPath' was not found; please try again." }
            } until ($pathOk)
            # A custom theme has no bundled identity, so color/icon fall back to neutral. Theme stays
            # 'screwcity' but is never emitted — -CustomTheme wins in the generated call.
            $newDef = Get-PwshProfileDefault
            $newDef.BannerColor = 'Silver'; $newDef.StepIcon = ':gear:'
            $newBranding = $neutral
            $s.Settings.Theme = 'screwcity'
            $s.Settings.CustomTheme = $customPath
        }
        else {
            $newDef = Get-PwshProfileDefault -Theme $pickTheme.Theme
            $newBranding = Get-BundledThemeBranding -Name $pickTheme.Theme
            $s.Settings.Theme = $pickTheme.Theme
            $s.Settings.CustomTheme = ''
        }

        # Re-seed only the color/icon fields the user hasn't customized away from the old theme.
        foreach ($k in 'BannerColor', 'StepIcon') {
            if ($s.Settings[$k] -eq $prevBranding[$k]) { $s.Settings[$k] = $newBranding[$k] }
        }
        # New branding baseline for pre-fills; the installer's own UI accent stays fixed.
        $s.Def = $newDef

        # Offer the matching Windows Terminal scheme so the palette lines up with the prompt.
        # A custom theme has none, so it falls back to the neutral Screw City scheme.
        $schemeName = (Get-BundledThemeBranding -Name $s.Settings.Theme).DisplayName
        $schemeHelp = if ($s.Settings.CustomTheme) {
            "A custom theme has no matching scheme, so this installs the neutral **$schemeName** Windows Terminal color scheme (it won''t match your custom prompt). Edits ``settings.json`` (backed up first); a no-op if Windows Terminal isn''t installed."
        }
        else {
            "Install the **$schemeName** Windows Terminal color scheme so the terminal's own palette matches your **oh-my-posh** prompt. Edits ``settings.json`` (backed up first); a no-op if Windows Terminal isn''t installed."
        }
        Write-PwshProfilePromptHelp $schemeHelp -Accent $s.Accent -Code $s.Code
        $s.Settings.SetSchemeDefault = $false
        if (Read-SpectreConfirm -Message 'Install the matching Windows Terminal color scheme?' -Color $s.Accent -DefaultAnswer 'n') {
            $s.Settings.InstallTerminalScheme = $true
            $s.Settings.SetSchemeDefault = [bool](Read-SpectreConfirm -Message 'Set it as the Windows Terminal default color scheme?' -Color $s.Accent -DefaultAnswer 'y')
        }
        else {
            $s.Settings.InstallTerminalScheme = $false
        }
    }

    # --- Step: Banner -----------------------------------------------------------------------
    $stepBanner = {
        param($s, $i, $total)
        Write-PwshProfileStepHeader -Title 'Banner' -Index $i -Total $total -Accent $s.Accent -Code $s.Code `
            -Body 'A large figlet banner printed once when the shell starts up — purely decorative.'

        # Show the current config, flagging anything off the theme default, then gate before prompting.
        $shown = -not $s.Settings.NoBanner
        $rows = @([pscustomobject]@{ Label = 'Banner'; Value = $(if ($shown) { 'shown' } else { 'hidden' }); Recommended = 'shown' })
        if ($shown) {
            $rows += [pscustomobject]@{ Label = 'Text';      Value = $s.Settings.BannerText;      Recommended = $s.Def.BannerText }
            $rows += [pscustomobject]@{ Label = 'Color';     Value = $s.Settings.BannerColor;     Recommended = $s.Def.BannerColor; Color = $true }
            $rows += [pscustomobject]@{ Label = 'Alignment'; Value = $s.Settings.BannerAlignment; Recommended = $s.Def.BannerAlignment }
            $rows += [pscustomobject]@{ Label = 'Font';      Value = $s.Settings.BannerFont;      Recommended = $s.Def.BannerFont }
        }
        if (-not (Read-PwshProfileSettingChange -Message 'Change these banner settings?' -Row $rows -Accent $s.Accent)) {
            return
        }

        if (Read-SpectreConfirm -Message 'Show a startup banner?' -Color $s.Accent -DefaultAnswer $(if ($s.Settings.NoBanner) { 'n' } else { 'y' })) {
            $s.Settings.NoBanner = $false
            Write-PwshProfilePromptHelp 'The text drawn in the banner. `$env:` variables are expanded, so `$env:COMPUTERNAME` shows the machine name. Press Enter to keep the default shown; clear it to hide the banner entirely.' -Accent $s.Accent -Code $s.Code
            $s.Settings.BannerText = Read-SpectreText -Message 'Banner text (supports $env: variables, e.g. $env:COMPUTERNAME)' -DefaultAnswer $s.Settings.BannerText -AllowEmpty
            if ([string]::IsNullOrWhiteSpace($s.Settings.BannerText)) {
                # Initialize-PwshProfile rejects an empty BannerText, so treat a cleared text as a
                # declined banner (restore the default, suppress via -NoBanner) instead of a blank one.
                $s.Settings.BannerText = $s.Def.BannerText
                $s.Settings.NoBanner = $true
                return
            }
            Write-PwshProfilePromptHelp 'Color of the banner text — a Spectre color name (e.g. `Aqua`) or a hex value (e.g. `#c9aaff`).' -Accent $s.Accent -Code $s.Code
            $s.Settings.BannerColor = Read-SpectreText -Message 'Banner color (Spectre color name or hex)' -DefaultAnswer $s.Settings.BannerColor
            # Echo a swatch under the raw value so the user sees the color. Guarded like the other echoes.
            if (Get-Command Write-SpectreHost -ErrorAction SilentlyContinue) {
                Write-SpectreHost "  [$($s.Accent)]✓[/] $(Format-PwshProfileColorValue $s.Settings.BannerColor)"
            }
            Write-PwshProfilePromptHelp 'Where the banner sits in the console width.' -Accent $s.Accent -Code $s.Code
            $s.Settings.BannerAlignment = Read-SpectreSelection -Message 'Banner alignment' -Color $s.Accent -Choices @('Left', 'Center', 'Right')
            Write-PwshProfilePromptAnswer $s.Settings.BannerAlignment -Accent $s.Accent

            # List the current font first so pressing Enter keeps it (selection menus can't pre-select).
            $fonts = @(Get-BundledFontName)
            $cur = $s.Settings.BannerFont
            if ($fonts -contains $cur) { $fonts = @($cur) + @($fonts | Where-Object { $_ -ne $cur }) }
            if ($fonts.Count -gt 0) {
                Write-PwshProfilePromptHelp 'The figlet (ASCII-art) typeface the banner text is rendered in.' -Accent $s.Accent -Code $s.Code
                $s.Settings.BannerFont = Read-SpectreSelection -Message 'Banner font' -Color $s.Accent -Choices $fonts -PageSize 10 -EnableSearch
                Write-PwshProfilePromptAnswer $s.Settings.BannerFont -Accent $s.Accent
            }
        }
        else {
            $s.Settings.NoBanner = $true
        }
    }

    # --- Step: Step icon (always) -----------------------------------------------------------
    $stepIcon = {
        param($s, $i, $total)
        Write-PwshProfileStepHeader -Title 'Step icon' -Index $i -Total $total -Accent $s.Accent -Code $s.Code `
            -Body 'The little glyph printed in front of every startup step line (e.g. installing/initializing each tool).'
        $iconOptions = @(
            [pscustomobject]@{ Label = '🔩  Nut and bolt';      Icon = ':nut_and_bolt:' }
            [pscustomobject]@{ Label = '🌳  Deciduous tree';    Icon = ':deciduous_tree:' }
            [pscustomobject]@{ Label = '⚙️  Gear';              Icon = ':gear:' }
            [pscustomobject]@{ Label = '🔧  Wrench';            Icon = ':wrench:' }
            [pscustomobject]@{ Label = '🛠️  Hammer and wrench'; Icon = ':hammer_and_wrench:' }
            [pscustomobject]@{ Label = '🚀  Rocket';            Icon = ':rocket:' }
            [pscustomobject]@{ Label = '✨  Sparkles';          Icon = ':sparkles:' }
            [pscustomobject]@{ Label = '⭐  Star';              Icon = ':star:' }
            [pscustomobject]@{ Label = 'Custom shortcode…';     Icon = $null }
        )
        # Float the current icon to the top and tag it so pressing Enter keeps it.
        $current = $iconOptions | Where-Object { $_.Icon -eq $s.Settings.StepIcon } | Select-Object -First 1
        if ($current) {
            $current.Label += ' (current)'
            $iconOptions = @($current) + @($iconOptions | Where-Object { $_ -ne $current })
        }
        $picked = Read-SpectreSelection -Message 'Step marker icon' -Color $s.Accent -Choices $iconOptions -ChoiceLabelProperty Label
        Write-PwshProfilePromptAnswer $picked.Label -Accent $s.Accent
        if ($null -eq $picked.Icon) {
            Write-PwshProfilePromptHelp 'A Spectre emoji shortcode wrapped in colons, e.g. `:gear:`. See `spectreconsole.net/emojis` for the full list.' -Accent $s.Accent -Code $s.Code
            $s.Settings.StepIcon = Read-SpectreText -Message 'Spectre emoji shortcode (e.g. ":gear:")' -DefaultAnswer $s.Settings.StepIcon
        }
        else {
            $s.Settings.StepIcon = $picked.Icon
        }
    }

    # --- Step: Features ---------------------------------------------------------------------
    $stepFeatures = {
        param($s, $i, $total)
        Write-PwshProfileStepHeader -Title 'Features' -Index $i -Total $total -Accent $s.Accent -Code $s.Code `
            -Body 'Choose which startup tools run (opt-in). **oh-my-posh** always draws the prompt; pick the rest.'
        $catalog = Get-PwshProfileToolCatalog -Token

        # Selection mode: a specific set, or everything including future additions. Current mode first.
        $modeSpecific = 'Pick specific tools'
        $modeAll = 'Enable everything, including tools added in future updates'
        $modeChoices = if ($s.Settings.EnableAll) { @($modeAll, $modeSpecific) } else { @($modeSpecific, $modeAll) }
        Write-PwshProfilePromptHelp @(
            '**Pick specific tools** — choose each tool yourself; nothing else installs, and tools added to the module later stay off until you re-run setup and select them.'
            '**Enable everything** — install every current tool *and* automatically adopt any tool added in future module updates, with no prompt. Convenient, but opts into future installs.'
        ) -Accent $s.Accent -Code $s.Code
        $mode = Read-SpectreSelection -Message 'How should startup tools be selected?' -Color $s.Accent -Choices $modeChoices
        Write-PwshProfilePromptAnswer $mode -Accent $s.Accent

        if ($mode -eq $modeAll) {
            # Everything on (and future tools auto-adopted); the tuning prompts below all apply.
            $s.Settings.EnableAll = $true
            $s.Settings.Enable = @($catalog)
            $selected = @($catalog)
        }
        else {
            $s.Settings.EnableAll = $false
            # Seed the tree from a genuine prior -Enable; otherwise from the clean-install default-on
            # set (Core checked, WinGet unchecked). New tools are tagged (new).
            $hasPriorEnable = ($PriorSetting -and $PriorSetting.ContainsKey('Enable'))
            $seed = if ($hasPriorEnable) { @($s.Settings.Enable) } else { @(Get-PwshProfileToolCatalog -DefaultEnabled) }
            $enabledMap = @{}
            foreach ($t in $catalog) { $enabledMap[$t] = ($seed -contains $t) }
            $selected = @(Read-PwshProfileFeatureTree -Enabled $enabledMap -New $NewTool -Color $s.Accent -CodeColor $s.Code)
            # Store in canonical catalog order.
            $s.Settings.Enable = @($catalog | Where-Object { $selected -contains $_ })
        }

        if ($selected -contains 'Zoxide') {
            Write-PwshProfilePromptHelp @(
                '**zoxide** is a smarter `cd`: it remembers the directories you visit most and lets you jump to one by a partial name — e.g. `cd dev` jumps straight to `C:\Dev` from anywhere.'
                'This sets the command name you type to do that. The default `cd` replaces the built-in cd (normal paths still work, it just gains the jump trick).'
                'Prefer `z` to leave the built-in cd untouched and add a separate `z` command (the zoxide convention). Press Enter to keep `cd`.'
            ) -Accent $s.Accent -Code $s.Code
            $s.Settings.ZoxideCommand = Read-SpectreText -Message "zoxide's jump command (replaces cd)" -DefaultAnswer $s.Settings.ZoxideCommand
        }

        if ($selected -contains 'Bat') {
            Write-PwshProfilePromptHelp @(
                '**bat** is a `cat` with syntax highlighting, line numbers, and git change marks; its colors are themed to match your prompt.'
                'Replace the built-in `cat` (an alias for `Get-Content`) with **bat**, so `cat file` renders highlighted? Plain redirection and piping still work.'
            ) -Accent $s.Accent -Code $s.Code
            $s.Settings.ReplaceCat = [bool](Read-SpectreConfirm -Message 'Replace the built-in cat (Get-Content) with bat?' -Color $s.Accent -DefaultAnswer 'y')
        }
        else {
            # bat is opted out, so the cat-override setting is moot — keep it off.
            $s.Settings.ReplaceCat = $false
        }

        if ($selected -contains 'Less') {
            Write-PwshProfilePromptHelp @(
                '**less** is a full-featured pager (color, search, backward scroll) — far beyond the built-in `more.com`; it is also what lets **bat** page with color.'
                'Make less the default pager? This sets `$env:PAGER` to less (so `help` and color CLIs page through it) and aliases `more` -> less. `more.com` stays available.'
            ) -Accent $s.Accent -Code $s.Code
            $s.Settings.ReplaceMore = [bool](Read-SpectreConfirm -Message 'Make less the default pager (replace more)?' -Color $s.Accent -DefaultAnswer 'y')
        }
        else {
            # less is opted out, so the pager-override setting is moot — keep it off.
            $s.Settings.ReplaceMore = $false
        }

        if ($selected -contains 'Fzf') {
            Write-PwshProfilePromptHelp @(
                '**PSFzf** can bind `Ctrl+G` chords for fzf-powered git pickers — branches, commits, changed files, stashes.'
                'With **lazygit** available for full git workflows these are off by default. Enable the PSFzf git keybindings (`Ctrl+G`)? `Ctrl+T` (files) and `Ctrl+R` (history) stay on regardless.'
            ) -Accent $s.Accent -Code $s.Code
            $s.Settings.FzfGitKeyBindings = [bool](Read-SpectreConfirm -Message 'Enable PSFzf git keybindings (Ctrl+G)?' -Color $s.Accent -DefaultAnswer 'n')

            Write-PwshProfilePromptHelp @(
                '**PSFzf** puts a fuzzy tab-completion picker on a chord; `Tab` itself stays `MenuComplete`.'
                'Which chord should trigger it? Press Enter to keep `Ctrl+Spacebar` (also binds `Ctrl+@`, which many terminals emit identically).'
            ) -Accent $s.Accent -Code $s.Code
            $s.Settings.FzfTabChord = Read-SpectreText -Message 'PSFzf tab-completion picker chord' -DefaultAnswer $s.Settings.FzfTabChord
        }
        else {
            # fzf is opted out, so the keybinding tuning is moot — keep the defaults.
            $s.Settings.FzfGitKeyBindings = $false
            $s.Settings.FzfTabChord = 'Ctrl+Spacebar'
        }
    }

    # --- Step: Nerd Font (optional) ---------------------------------------------------------
    $stepFonts = {
        param($s, $i, $total)
        Write-PwshProfileStepHeader -Title 'Nerd Font' -Index $i -Total $total -Accent $s.Accent -Code $s.Code `
            -Body '**oh-my-posh** prompts use special icons (folder, git, OS glyphs) that only render in a "Nerd Font" — a normal font patched with those extra symbols.'
        Write-PwshProfilePromptHelp 'Say yes to install the recommended **Meslo** + **CascadiaCode** pair (then set one as your terminal font and the prompt renders right instead of showing boxes); no installs nothing. Downloads to your user profile; no admin needed.' -Accent $s.Accent -Code $s.Code
        $s.Settings.NerdFont = $null
        if (Read-SpectreConfirm -Message 'Install Nerd Fonts (Meslo + CascadiaCode) for the prompt glyphs? (download, no admin needed)' -Color $s.Accent -DefaultAnswer 'n') {
            # Ensure the NerdFonts module so its font catalog is queryable.
            Import-ModuleSafe NerdFonts
            if (Get-Command Get-NerdFont -ErrorAction SilentlyContinue) {
                $names = @(Get-NerdFont | Select-Object -ExpandProperty Name)
                # Recommended pairing for oh-my-posh, minus anything absent from the catalog.
                $recommended = @('Meslo', 'CascadiaCode') | Where-Object { $names -contains $_ }
                if ($recommended.Count -gt 0) {
                    $s.Settings.NerdFont = $recommended
                }
                else {
                    Write-Warning 'Invoke-PwshProfileWizard: neither recommended font (Meslo, CascadiaCode) is in the NerdFonts catalog; skipping font install.'
                }
            }
            else {
                Write-Warning 'Invoke-PwshProfileWizard: the NerdFonts module is unavailable; skipping font installation.'
            }
        }

        # Asked every run, even if the install above was declined — the font may already be present.
        Write-PwshProfilePromptHelp 'Point **Windows Terminal** at `MesloLGM Nerd Font` as its default profile font so the prompt glyphs render right away. Edits its `settings.json` (backed up first); a no-op if Windows Terminal isn''t installed.' -Accent $s.Accent -Code $s.Code
        $s.Settings.SetTerminalFont = [bool](Read-SpectreConfirm -Message 'Set MesloLGM Nerd Font as the Windows Terminal default font?' -Color $s.Accent -DefaultAnswer 'n')
    }

    # --- Step: Winget settings --------------------------------------------------------------
    $stepWinget = {
        param($s, $i, $total)
        Write-PwshProfileStepHeader -Title 'Winget' -Index $i -Total $total -Accent $s.Accent -Code $s.Code `
            -Body 'Tunes the **winget** client itself — the defaults in its `settings.json` that apply whenever you install packages. Applied once now; pre-filled from your current winget settings.'

        # Show the current values (flagging any off the recommendation), then gate before prompting.
        $rec = Get-WingetSettingRecommended
        $rows = @(
            [pscustomobject]@{ Label = 'Default scope';   Value = $s.Settings.WingetScope;       Recommended = $rec.Scope }
            [pscustomobject]@{ Label = 'Progress bar';    Value = $s.Settings.WingetProgressBar; Recommended = $rec.ProgressBar }
            [pscustomobject]@{ Label = 'Anonymize paths'; Value = $(if ($s.Settings.WingetAnonymizePath) { 'on' } else { 'off' });          Recommended = $(if ($rec.AnonymizePath) { 'on' } else { 'off' }) }
            [pscustomobject]@{ Label = 'Install notes';   Value = $(if ($s.Settings.WingetDisableInstallNote) { 'suppressed' } else { 'shown' }); Recommended = $(if ($rec.DisableInstallNote) { 'suppressed' } else { 'shown' }) }
        )
        if (-not (Read-PwshProfileSettingChange -Message 'Change these winget settings?' -Row $rows -Accent $s.Accent)) {
            return
        }

        # Default install scope — float the current value first so pressing Enter keeps it.
        Write-PwshProfilePromptHelp 'Whether `winget install` targets the current **user** (no admin prompt) or the whole **machine** by default. `user` is preferred and falls back to machine when a package has no per-user installer, so it never blocks an install.' -Accent $s.Accent -Code $s.Code
        $scopes = @('user', 'machine')
        if ($scopes -contains $s.Settings.WingetScope) {
            $scopes = @($s.Settings.WingetScope) + @($scopes | Where-Object { $_ -ne $s.Settings.WingetScope })
        }
        $s.Settings.WingetScope = Read-SpectreSelection -Message 'Default install scope (winget)' -Color $s.Accent -Choices $scopes
        Write-PwshProfilePromptAnswer $s.Settings.WingetScope -Accent $s.Accent

        # Progress bar style — float the current value first.
        Write-PwshProfilePromptHelp 'The bar **winget** shows while downloading/installing: `rainbow` is a cycling gradient, `accent` a solid accent-color bar, `retro` a plain ASCII bar, `sixel` a graphical bar on terminals that support it, `disabled` none.' -Accent $s.Accent -Code $s.Code
        $bars = @('accent', 'rainbow', 'retro', 'sixel', 'disabled')
        if ($bars -contains $s.Settings.WingetProgressBar) {
            $bars = @($s.Settings.WingetProgressBar) + @($bars | Where-Object { $_ -ne $s.Settings.WingetProgressBar })
        }
        $s.Settings.WingetProgressBar = Read-SpectreSelection -Message 'Winget progress bar style' -Color $s.Accent -Choices $bars
        Write-PwshProfilePromptAnswer $s.Settings.WingetProgressBar -Accent $s.Accent

        Write-PwshProfilePromptHelp 'Replace known folders with their environment-variable names (e.g. `%LOCALAPPDATA%`) in **winget** output — handy for screenshots and screen-sharing.' -Accent $s.Accent -Code $s.Code
        $s.Settings.WingetAnonymizePath = [bool](Read-SpectreConfirm -Message 'Anonymize known paths in winget output?' -Color $s.Accent -DefaultAnswer $(if ($s.Settings.WingetAnonymizePath) { 'y' } else { 'n' }))

        Write-PwshProfilePromptHelp 'Suppress the notes some packages print after a successful install, for quieter output.' -Accent $s.Accent -Code $s.Code
        $s.Settings.WingetDisableInstallNote = [bool](Read-SpectreConfirm -Message 'Suppress post-install notes?' -Color $s.Accent -DefaultAnswer $(if ($s.Settings.WingetDisableInstallNote) { 'y' } else { 'n' }))
    }

    # Ordered step table — drives the forward pass and the review hub's Edit choices. Theme must stay
    # ahead of Banner and Step icon, which pre-fill from the branding it seeds.
    $steps = [ordered]@{
        'Fonts'     = $stepFonts
        'Winget'    = $stepWinget
        'Theme'     = $stepTheme
        'Banner'    = $stepBanner
        'Step icon' = $stepIcon
        'Features'  = $stepFeatures
    }

    # Forward pass — thread each step's 1-based position and the total so its header shows "N of M".
    $keys = @($steps.Keys)
    $total = $keys.Count
    for ($n = 0; $n -lt $total; $n++) { & $steps[$keys[$n]] $state ($n + 1) $total }

    # --- Review hub -------------------------------------------------------------------------
    # Escape user-controlled text (banner text/color, custom path, icon shortcode) via $esc before
    # tinting it, so it can never inject markup. Known-safe slugs are tinted directly.
    $accent = $state.Accent
    $code = $state.Code
    while ($true) {
        $set = $state.Settings
        $themeLine = if ($set.CustomTheme) {
            "custom: [$code]$(ConvertTo-EscapedText $set.CustomTheme)[/]"
        }
        else { "[$accent]$($set.Theme)[/]" }
        $bannerOff = [bool]$set.NoBanner
        $bannerLine = if ($bannerOff) {
            '[grey]off[/]'
        }
        else {
            "'$(ConvertTo-EscapedText $set.BannerText)' [grey]/[/] $(Format-PwshProfileColorValue $set.BannerColor) [grey]/[/] $($set.BannerAlignment) [grey]/[/] [$code]$($set.BannerFont)[/]"
        }
        # Feature summary: everything (and future), the chosen set, or nothing.
        $enabledList = @($set.Enable)
        $featuresLine = if ($set.EnableAll) {
            '[grey]all tools + future additions[/]'
        }
        elseif ($enabledList.Count -gt 0) {
            "[$code]$($enabledList -join ', ')[/]"
        }
        else { '[grey]none[/]' }
        $batOn = $set.EnableAll -or ($enabledList -contains 'Bat')
        $lessOn = $set.EnableAll -or ($enabledList -contains 'Less')
        $fzfOn = $set.EnableAll -or ($enabledList -contains 'Fzf')
        if ($set.ReplaceCat -and $batOn) {
            $featuresLine += " [grey]·[/] [$code]cat→bat[/]"
        }
        if ($set.ReplaceMore -and $lessOn) {
            $featuresLine += " [grey]·[/] [$code]more→less[/]"
        }
        # Note fzf keybinding tuning: git chords, and/or a non-default tab chord.
        if ($fzfOn) {
            if ($set.FzfGitKeyBindings) { $featuresLine += " [grey]·[/] [$code]git chords[/]" }
            if ($set.FzfTabChord -and $set.FzfTabChord -ne 'Ctrl+Spacebar') {
                $featuresLine += " [grey]·[/] [$code]tab: $(ConvertTo-EscapedText $set.FzfTabChord)[/]"
            }
        }
        $fontsLine = if (@($set.NerdFont).Count -gt 0) {
            (@($set.NerdFont) | ForEach-Object { "[$accent]$_[/]" }) -join ', '
        }
        else { '[grey]none[/]' }
        $wtFontLine = if ($set.SetTerminalFont) { "[$accent]MesloLGM Nerd Font[/]" } else { '[grey]unchanged[/]' }
        $wtSchemeLine = if ($set.InstallTerminalScheme) {
            $schemeNm = (Get-BundledThemeBranding -Name $set.Theme).DisplayName
            if ($set.SetSchemeDefault) { "[$accent]$schemeNm[/] [grey](default)[/]" } else { "[$accent]$schemeNm[/]" }
        }
        else { '[grey]none[/]' }
        $anon = if ($set.WingetAnonymizePath) { 'on' } else { 'off' }
        $notes = if ($set.WingetDisableInstallNote) { 'off' } else { 'on' }
        $wingetLine = "scope [$accent]$($set.WingetScope)[/] [grey]·[/] bar [$accent]$($set.WingetProgressBar)[/] [grey]·[/] anon paths $anon [grey]·[/] install notes $notes"

        $summary = @(
            "[bold]Theme:[/]      $themeLine"
            "[bold]Banner:[/]     $bannerLine"
            "[bold]Step icon:[/]  [$code]$(ConvertTo-EscapedText $set.StepIcon)[/]"
            "[bold]Features:[/]   $featuresLine"
            "[bold]Nerd Fonts:[/] $fontsLine"
            "[bold]WT font:[/]    $wtFontLine"
            "[bold]WT scheme:[/]  $wtSchemeLine"
            "[bold]Winget:[/]     $wingetLine"
        ) -join "`n"
        $summary | Format-SpectrePanel -Header '◆ Review your setup' -Border Rounded -Color $accent -Expand | Out-Host

        $submit = 'Submit — write the profile'
        $cancel = 'Cancel — exit without writing'
        $choices = @($submit) + @($keys | ForEach-Object { "Edit $_" }) + @($cancel)
        $pick = Read-SpectreSelection -Message 'What would you like to do?' -Color $accent -Choices $choices

        if ($pick -eq $submit) { break }
        if ($pick -eq $cancel) { return $null }
        $editName = $pick -replace '^Edit ', ''
        & $steps[$editName] $state ([array]::IndexOf($keys, $editName) + 1) $total
    }

    $state.Settings
}
