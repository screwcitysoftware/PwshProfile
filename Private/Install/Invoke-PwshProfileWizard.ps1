function Invoke-PwshProfileWizard {
    <#
    .SYNOPSIS
        Runs the interactive Install-PwshProfile setup wizard and returns the chosen settings (or
        $null if the user cancels).

    .DESCRIPTION
        Drives the PwshSpectreConsole prompts that collect the user's profile configuration and
        returns a settings hashtable (the keys of Get-PwshProfileDefault, plus a NerdFont key
        holding the chosen Nerd Font name(s) as an array, or $null when none were selected, plus the
        WingetScope / WingetProgressBar / WingetAnonymizePath / WingetDisableInstallNote keys carrying
        the chosen winget client settings). If the user cancels at the review screen, it returns $null
        and Install-PwshProfile writes nothing.

        Each step opens with a rounded header panel (Write-PwshProfileStepHeader) carrying the step
        title, a "N of M" progress counter, and a primary description; secondary prompts get inline
        hint lines (Write-PwshProfilePromptHelp). Both run their text through Format-PwshProfileHelpMarkup,
        so tool names and code literals are highlighted rather than flat grey — users unfamiliar with
        the underlying tools (zoxide and its jump command especially) aren't left guessing.

        Selection prompts (Read-SpectreSelection) clear themselves on submit, unlike the text prompts
        that leave their answer on screen, so each selection's chosen value is echoed afterward via
        Write-PwshProfilePromptAnswer (an accent check mark + the value) to keep a visible record.

        The wizard makes one forward pass through the steps, then lands on a review hub where any
        step can be re-edited before submitting, or the whole thing cancelled:

          1. Nerd Fonts: optional, a single yes/no; on yes, ensures the NerdFonts module and installs
             the recommended Meslo + CascadiaCode pair; on no, nothing is installed.
          2. Winget: a curated set of winget client settings (default install scope, progress-bar
             style, anonymize-displayed-paths, suppress-install-notes). It first shows the current
             values (pre-filled from the live settings.json via Get-WingetSettingDefault, flagging any
             that differ from the recommendation) and asks whether to change them — defaulting to No,
             via Read-PwshProfileSettingChange — only prompting per-setting on Yes. The values are
             applied to settings.json at install time by Install-PwshProfile via Set-WingetSetting
             (not baked into the bootstrap call).
          3. Theme: pick a bundled oh-my-posh theme (screwcity / forestcity) or supply a custom theme
             path. The bundled choice seeds the banner color and step icon the later prompts are
             pre-filled with; a custom path seeds neutral color/icon (a neutral color, a generic icon)
             so you define those fresh. The banner text defaults to the machine name regardless of
             theme. Re-picking a theme later preserves any color/icon you already customized (only
             still-default fields are re-seeded).
          4. Banner: shows the current banner config (shown/hidden plus text/color/alignment/font,
             flagging anything off the theme default) and asks whether to change it — defaulting to No,
             via Read-PwshProfileSettingChange. On Yes it asks a show/hide yes-no (no disables the
             banner via -Skip Banner and skips the theming sub-steps; yes prompts text, color,
             alignment, and bundled font). Clearing the banner text also hides the banner — an empty
             text renders nothing at startup, so it's treated like a declined banner (-Skip Banner,
             default text restored) rather than left as a shown-but-blank half-state.
          5. Step icon: always asked (the icon marks every startup step, banner or not) — a curated
             shortcode menu with the current icon floated to the top, plus a "custom shortcode" escape.
          6. Features: a grouped, all-checked-by-default tree (Read-PwshProfileFeatureTree) under the
             Shell / Prompt / Tools sections (shell completions sit under Tools); unchecking opts a
             feature (or a whole section) out, mapped to -Skip / -SkipSection. oh-my-posh is always on
             and not listed. If zoxide stays enabled, its jump command is prompted.

        Then a review panel summarizes the choices and offers Submit / Edit <step> / Cancel.

        Assumes the Spectre prompt cmdlets are available — Install-PwshProfile guards that and
        falls back to defaults when they are not.

    .PARAMETER Reconfiguring
        Indicates the target profile already contains a managed block, so the intro line can say it
        is updating rather than creating. Purely cosmetic.

    .EXAMPLE
        Invoke-PwshProfileWizard

        Walks the user through the prompts and returns the resulting settings hashtable (or $null if
        cancelled).
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Reconfiguring
    )

    # Shared mutable state, passed by reference into every step so edits from the review hub stick.
    # Settings is the hashtable returned to the caller; Def is the baseline for the *current* theme
    # (drives pre-fills and the "still default?" preserve-edits check); Accent / Code are the
    # installer's own UI colors — fixed at the module's signature purple and a soft cyan, and
    # intentionally decoupled from the prompt theme being configured, so the wizard (panels, accents,
    # code-literal highlighting) looks the same whichever theme you pick.
    $def = Get-PwshProfileDefault
    $settings = $def.Clone()
    $settings.NerdFont = $null
    # winget client settings (applied to winget's settings.json at install time, like NerdFont — not
    # part of the Initialize-PwshProfile bootstrap, so Build-PwshProfileInitializeCall ignores them).
    # Seed from the live settings file: an explicitly-set value becomes the pre-fill, otherwise the
    # module default (Get-WingetSettingDefault).
    $wingetDef = Get-WingetSettingDefault
    $settings.WingetScope = $wingetDef.Scope
    $settings.WingetProgressBar = $wingetDef.ProgressBar
    $settings.WingetAnonymizePath = $wingetDef.AnonymizePath
    $settings.WingetDisableInstallNote = $wingetDef.DisableInstallNote
    $state = @{ Settings = $settings; Def = $def; Accent = '#c9aaff'; Code = '#5fd7ff' }

    # Escape a dynamic value for safe inclusion in Spectre markup (banner text, paths, …).
    $esc = {
        param($text)
        if ([string]::IsNullOrEmpty("$text")) { return '' }
        Get-SpectreEscapedTextSafe -Text "$text"
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
        # Float the default theme (screwcity) to the top so pressing Enter keeps it.
        $themeChoices = @($themeChoices | Where-Object { $_.Theme -eq 'screwcity' }) +
                        @($themeChoices | Where-Object { $_.Theme -ne 'screwcity' })
        $pickTheme = Read-SpectreSelection -Message 'Choose an oh-my-posh theme' -Color $s.Accent -Choices $themeChoices -ChoiceLabelProperty Label
        Write-PwshProfilePromptAnswer $pickTheme.Label -Accent $s.Accent

        # The branding (color/icon) the current fields were seeded from, so we only re-seed untouched
        # ones. Banner text is theme-independent ($env:COMPUTERNAME default), so it's not re-seeded.
        $neutral = @{ BannerColor = 'Silver'; StepIcon = ':gear:' }
        $prevBranding = if ($s.Settings.CustomTheme) { $neutral } else { Get-BundledThemeBranding -Name $s.Settings.Theme }

        if ($pickTheme.Custom) {
            do {
                Write-PwshProfilePromptHelp 'Enter the full path to an **oh-my-posh** theme file (a `.omp.json`) on disk.' -Accent $s.Accent -Code $s.Code
                $customPath = Read-SpectreText -Message 'Path to your custom oh-my-posh theme (.omp.json)'
                $pathOk = $customPath -and (Test-Path -Path $customPath)
                if (-not $pathOk) { Write-Warning "Theme path '$customPath' was not found; please try again." }
            } until ($pathOk)
            # A custom theme has no bundled identity, so its color/icon baseline is NEUTRAL. The banner
            # text keeps the uniform $env:COMPUTERNAME default. Theme stays 'screwcity' but is never
            # emitted, since -CustomTheme takes precedence in the generated call.
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

        # Re-seed only the color/icon fields the user hasn't customized away from the old theme's
        # values (banner text is theme-independent, so it's never re-seeded here).
        foreach ($k in 'BannerColor', 'StepIcon') {
            if ($s.Settings[$k] -eq $prevBranding[$k]) { $s.Settings[$k] = $newBranding[$k] }
        }
        # Update the branding baseline (pre-fills + preserve-edits check) but leave the installer's
        # UI accent fixed — it doesn't follow the selected prompt theme.
        $s.Def = $newDef
    }

    # --- Step: Banner -----------------------------------------------------------------------
    $stepBanner = {
        param($s, $i, $total)
        Write-PwshProfileStepHeader -Title 'Banner' -Index $i -Total $total -Accent $s.Accent -Code $s.Code `
            -Body 'A large figlet banner printed once when the shell starts up — purely decorative.'

        # Show the current banner config, flagging anything off the theme default, then gate (default
        # No) before prompting. Recommended baseline is the current theme's branding ($s.Def).
        $shown = (@($s.Settings.Skip) -notcontains 'Banner')
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

        if (Read-SpectreConfirm -Message 'Show a startup banner?' -Color $s.Accent -DefaultAnswer 'y') {
            $s.Settings.Skip = @(@($s.Settings.Skip) | Where-Object { $_ -ne 'Banner' })
            Write-PwshProfilePromptHelp 'The text drawn in the banner. `$env:` variables are expanded, so `$env:COMPUTERNAME` shows the machine name. Press Enter to keep the default shown; clear it to hide the banner entirely.' -Accent $s.Accent -Code $s.Code
            $s.Settings.BannerText = Read-SpectreText -Message 'Banner text (supports $env: variables, e.g. $env:COMPUTERNAME)' -DefaultAnswer $s.Settings.BannerText -AllowEmpty
            if ([string]::IsNullOrWhiteSpace($s.Settings.BannerText)) {
                # An empty banner text renders no banner at startup (Initialize-PwshProfile guards on
                # it), so treat a cleared text like a declined banner: restore the default text and
                # hide via -Skip Banner, rather than leaving a "shown but blank" half-state in the
                # review summary and generated call. Skip the remaining theming prompts.
                $s.Settings.BannerText = $s.Def.BannerText
                $s.Settings.Skip = @(@($s.Settings.Skip) + 'Banner' | Select-Object -Unique)
                return
            }
            Write-PwshProfilePromptHelp 'Color of the banner text — a Spectre color name (e.g. `Aqua`) or a hex value (e.g. `#c9aaff`).' -Accent $s.Accent -Code $s.Code
            $s.Settings.BannerColor = Read-SpectreText -Message 'Banner color (Spectre color name or hex)' -DefaultAnswer $s.Settings.BannerColor
            # Echo the chosen color as a swatch so the user sees what it looks like (Read-SpectreText
            # leaves the raw value on screen; this adds the colored preview beneath it). Guarded like the
            # other prompt-echo helpers so it no-ops when Spectre is unavailable.
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
            # No banner: disable it via -Skip Banner (deduped), leaving feature skips intact.
            $s.Settings.Skip = @(@($s.Settings.Skip) + 'Banner' | Select-Object -Unique)
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
            -Body 'Pick which startup features run — everything is checked by default, so uncheck to opt out. **oh-my-posh** always runs and has no checkbox.'
        $skip = @($s.Settings.Skip)
        # Current checked state per feature token (everything on unless previously skipped).
        $enabledMap = @{
            PSReadLine    = ($skip -notcontains 'PSReadLine')
            TerminalIcons = ($skip -notcontains 'TerminalIcons')
            PoshGit       = ($skip -notcontains 'PoshGit')
            Zoxide        = ($skip -notcontains 'Zoxide')
            Fzf           = ($skip -notcontains 'Fzf')
            Fnm           = ($skip -notcontains 'Fnm')
            Xh            = ($skip -notcontains 'Xh')
            Bat           = ($skip -notcontains 'Bat')
            Fd            = ($skip -notcontains 'Fd')
            Less          = ($skip -notcontains 'Less')
            Completions   = ($skip -notcontains 'Completions')
        }
        $selected = @(Read-PwshProfileFeatureTree -Enabled $enabledMap -Color $s.Accent -CodeColor $s.Code)

        # Anything unchecked becomes an individual -Skip token (Completions included — it runs as a
        # sub-step under Tools); keep the Banner skip (owned by the banner step). The wizard never
        # emits -SkipSection: unchecking a whole section in the tree just unchecks its leaves.
        $newSkip = @(@($skip | Where-Object { $_ -eq 'Banner' }))
        foreach ($t in 'PSReadLine', 'TerminalIcons', 'PoshGit', 'Zoxide', 'Fzf', 'Fnm', 'Xh', 'Bat', 'Fd', 'Less', 'Completions') {
            if ($selected -notcontains $t) { $newSkip += $t }
        }
        $s.Settings.Skip = $newSkip
        $s.Settings.SkipSection = @()

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
                # Meslo + CascadiaCode are the recommended pairing for oh-my-posh; keep only those
                # actually present in the catalog ("if possible").
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
    }

    # --- Step: Winget settings --------------------------------------------------------------
    $stepWinget = {
        param($s, $i, $total)
        Write-PwshProfileStepHeader -Title 'Winget' -Index $i -Total $total -Accent $s.Accent -Code $s.Code `
            -Body 'Tunes the **winget** client itself — the defaults in its `settings.json` that apply whenever you install packages. Applied once now; pre-filled from your current winget settings.'

        # Show the current values (flagging any off the recommendation), then gate (default No) before
        # prompting. The current values are applied at install time either way.
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
        Write-PwshProfilePromptHelp 'The bar **winget** shows while downloading/installing: `rainbow` is a cycling gradient, `accent` a solid accent-color bar, `retro` a plain ASCII bar, `disabled` none.' -Accent $s.Accent -Code $s.Code
        $bars = @('accent', 'rainbow', 'retro', 'disabled')
        if ($bars -contains $s.Settings.WingetProgressBar) {
            $bars = @($s.Settings.WingetProgressBar) + @($bars | Where-Object { $_ -ne $s.Settings.WingetProgressBar })
        }
        $s.Settings.WingetProgressBar = Read-SpectreSelection -Message 'Winget progress bar style' -Color $s.Accent -Choices $bars
        Write-PwshProfilePromptAnswer $s.Settings.WingetProgressBar -Accent $s.Accent

        # Anonymize displayed paths.
        Write-PwshProfilePromptHelp 'Replace known folders with their environment-variable names (e.g. `%LOCALAPPDATA%`) in **winget** output — handy for screenshots and screen-sharing.' -Accent $s.Accent -Code $s.Code
        $s.Settings.WingetAnonymizePath = [bool](Read-SpectreConfirm -Message 'Anonymize known paths in winget output?' -Color $s.Accent -DefaultAnswer $(if ($s.Settings.WingetAnonymizePath) { 'y' } else { 'n' }))

        # Suppress post-install notes.
        Write-PwshProfilePromptHelp 'Suppress the notes some packages print after a successful install, for quieter output.' -Accent $s.Accent -Code $s.Code
        $s.Settings.WingetDisableInstallNote = [bool](Read-SpectreConfirm -Message 'Suppress post-install notes?' -Color $s.Accent -DefaultAnswer $(if ($s.Settings.WingetDisableInstallNote) { 'y' } else { 'n' }))
    }

    # Ordered step table — drives both the forward pass and the review hub's Edit choices. The two
    # machine-setup steps (Nerd Fonts, Winget) lead; the prompt cosmetics follow. Theme must stay
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
    # Color the values directly: known-safe slugs (theme/font/feature tokens) get a color tag, while
    # user-controlled text (banner text/color, custom path, icon shortcode) is escaped via $esc first
    # so it can never inject markup — then tinted. Labels stay bold.
    $accent = $state.Accent
    $code = $state.Code
    while ($true) {
        $set = $state.Settings
        $themeLine = if ($set.CustomTheme) {
            "custom: [$code]$(& $esc $set.CustomTheme)[/]"
        }
        else { "[$accent]$($set.Theme)[/]" }
        $bannerOff = (@($set.Skip) -contains 'Banner')
        $bannerLine = if ($bannerOff) {
            '[grey]off[/]'
        }
        else {
            "'$(& $esc $set.BannerText)' [grey]/[/] $(Format-PwshProfileColorValue $set.BannerColor) [grey]/[/] $($set.BannerAlignment) [grey]/[/] [$code]$($set.BannerFont)[/]"
        }
        $disabled = @(@($set.Skip) | Where-Object { $_ -ne 'Banner' }) + @($set.SkipSection)
        $featuresLine = if ($disabled.Count) {
            "all except [$code]$($disabled -join ', ')[/]"
        }
        else { '[grey]all enabled[/]' }
        # Note the cat -> bat takeover, when opted in and bat is still enabled.
        if ($set.ReplaceCat -and (@($set.Skip) -notcontains 'Bat')) {
            $featuresLine += " [grey]·[/] [$code]cat→bat[/]"
        }
        # Note the more -> less takeover, when opted in and less is still enabled.
        if ($set.ReplaceMore -and (@($set.Skip) -notcontains 'Less')) {
            $featuresLine += " [grey]·[/] [$code]more→less[/]"
        }
        $fontsLine = if (@($set.NerdFont).Count) {
            (@($set.NerdFont) | ForEach-Object { "[$accent]$_[/]" }) -join ', '
        }
        else { '[grey]none[/]' }
        $anon = if ($set.WingetAnonymizePath) { 'on' } else { 'off' }
        $notes = if ($set.WingetDisableInstallNote) { 'off' } else { 'on' }
        $wingetLine = "scope [$accent]$($set.WingetScope)[/] [grey]·[/] bar [$accent]$($set.WingetProgressBar)[/] [grey]·[/] anon paths $anon [grey]·[/] install notes $notes"

        $summary = @(
            "[bold]Theme:[/]      $themeLine"
            "[bold]Banner:[/]     $bannerLine"
            "[bold]Step icon:[/]  [$code]$(& $esc $set.StepIcon)[/]"
            "[bold]Features:[/]   $featuresLine"
            "[bold]Nerd Fonts:[/] $fontsLine"
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
