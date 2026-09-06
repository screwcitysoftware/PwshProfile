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
          2. Winget: the full list of CLI packages setup is about to install (Show-PwshProfileInventory
             over Get-PwshProfileToolInventory), then a curated set of winget client settings (install
             scope, progress bar, anonymize paths, suppress install notes), pre-filled from the live
             settings.json and gated behind a single "change these?" prompt that defaults to No. The
             list frames those questions rather than trailing them.
          3. Modules: disclosure only — the PowerShell Gallery modules the profile installs on demand,
             marked present, will-install, or conditional. Nothing to answer, so it ends on a bare
             "press Enter" rather than a question it does not have.
          4. Theme: a bundled oh-my-posh theme or a custom path. The bundled choice seeds every branded
             setting later prompts pre-fill from (banner color, step icon, bat theme); a custom path
             seeds neutral ones. Re-picking a theme preserves any of those already customized. It then
             offers the matching Windows Terminal color scheme, and if accepted, whether to make it
             the default.
          5. Banner: shows the current config and gates the per-setting prompts behind the same
             "change these?" pattern. Clearing the banner text hides the banner — since BannerText must
             be non-empty, a cleared text becomes -NoBanner rather than a shown-but-blank half-state.
          6. Step icon: always asked, since the icon marks every startup step whether or not there is a
             banner. A curated shortcode menu with the current icon floated to the top, plus a custom
             escape hatch.
          7. Wiring: every tool is installed and enabled, so this asks only how they wire into the
             shell. A grouped checkbox tree (Read-PwshProfileWiringTree, sourced from
             Get-PwshProfileWiringCatalog) covers the binary choices — which commands get taken over,
             and the Ctrl+G git chords — then the free-text settings a checkbox can't express follow:
             bat's theme and style, less's options, and the fzf tab chord.

        The font, winget, and terminal-scheme choices are one-time machine actions applied by
        Install-PwshProfile, not baked into the bootstrap call.

        Assumes the Spectre prompt cmdlets are available — Install-PwshProfile guards that and warns
        that an interactive session is required when they are not.

    .PARAMETER PriorSetting
        On a re-run, the settings parsed from the existing block via Read-PwshProfileInstalledSetting,
        used to seed every prompt with last time's choice.

    .EXAMPLE
        Invoke-PwshProfileWizard

        Walks the prompts and returns the resulting settings hashtable, or $null if cancelled.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [hashtable]$PriorSetting
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

        # Every branded setting, and the branding the current values were seeded from, so only
        # untouched ones get re-seeded. Driving this off the schema is what makes BatTheme ride along:
        # it is branded exactly like BannerColor and StepIcon, and was previously left out of this
        # list, so switching theme wrote the old theme's bat palette into the new theme's profile.
        $themedRow = @(Get-PwshProfileSettingSchema -Wizard | Where-Object BrandingKey)
        $prevBranding = if ($s.Settings.CustomTheme) { $null } else { Get-BundledThemeBranding -Name $s.Settings.Theme }

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
            foreach ($row in $themedRow) { $newDef[$row.Name] = $row.Neutral }
            $newBranding = $null
            $s.Settings.Theme = 'screwcity'
            $s.Settings.CustomTheme = $customPath
        }
        else {
            $newDef = Get-PwshProfileDefault -Theme $pickTheme.Theme
            $newBranding = Get-BundledThemeBranding -Name $pickTheme.Theme
            $s.Settings.Theme = $pickTheme.Theme
            $s.Settings.CustomTheme = ''
        }

        # Re-seed only the branded fields the user hasn't customized away from the old theme. A null
        # branding means the theme on that side was custom, which has no bundled identity — the row's
        # Neutral stands in. Settings are keyed by Name and branding by BrandingKey: not the same
        # namespace, which is why the schema names the member rather than assuming they match.
        foreach ($row in $themedRow) {
            $prev = if ($prevBranding) { $prevBranding[$row.BrandingKey] } else { $row.Neutral }
            $next = if ($newBranding) { $newBranding[$row.BrandingKey] } else { $row.Neutral }
            if ($s.Settings[$row.Name] -eq $prev) { $s.Settings[$row.Name] = $next }
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

    # --- Step: Wiring -----------------------------------------------------------------------
    $stepWiring = {
        param($s, $i, $total)
        Write-PwshProfileStepHeader -Title 'Wiring' -Index $i -Total $total -Accent $s.Accent -Code $s.Code `
            -Body 'Every tool is installed and enabled. These choose how they wire into your shell — which existing commands they take over, and how the themed ones look.'

        # The binary choices, all on one screen. Returns setting -> value for EVERY row, checked or
        # not, so an unchecked box records a real "no" rather than leaving the prior run's value.
        $chosen = Read-PwshProfileWiringTree -Setting $s.Settings -Color $s.Accent -CodeColor $s.Code
        foreach ($key in $chosen.Keys) { $s.Settings[$key] = $chosen[$key] }

        # Free-text settings a checkbox can't express, prompted after the tree.
        #
        # Pre-filled from the selected theme's branding, so pressing Enter keeps bat matching the
        # prompt. A text prompt rather than a menu on purpose: the wizard still runs before the tool
        # install step, so `bat --list-themes` has nothing to enumerate yet.
        Write-PwshProfilePromptHelp @(
            'The syntax-highlighting theme **bat** uses, from `bat --list-themes`. It is pre-filled to match your prompt theme; `ansi` follows your terminal''s own colors.'
        ) -Accent $s.Accent -Code $s.Code
        $s.Settings.BatTheme = Read-SpectreText -Message 'bat syntax theme' -DefaultAnswer $s.Settings.BatTheme

        Write-PwshProfilePromptHelp @(
            'Which parts **bat** draws around your file: a comma-separated list of `numbers`, `changes` (git marks), `header`, `grid`, `rule`, `snip`. Use `full` for everything or `plain` for none.'
        ) -Accent $s.Accent -Code $s.Code
        $s.Settings.BatStyle = Read-SpectreText -Message 'bat style components' -DefaultAnswer $s.Settings.BatStyle

        Write-PwshProfilePromptHelp @(
            'The options **less** applies to every invocation, via `$env:LESS`. The default `-R -F -i` means: pass color through, quit if the text fits one screen, and search case-insensitively.'
        ) -Accent $s.Accent -Code $s.Code
        $s.Settings.LessOptions = Read-SpectreText -Message 'less options ($env:LESS)' -DefaultAnswer $s.Settings.LessOptions

        Write-PwshProfilePromptHelp @(
            '**PSFzf** puts a fuzzy tab-completion picker on a chord; `Tab` itself stays `MenuComplete`.'
            'Which chord should trigger it? Press Enter to keep `Ctrl+Spacebar` (also binds `Ctrl+@`, which many terminals emit identically).'
        ) -Accent $s.Accent -Code $s.Code
        $s.Settings.FzfTabChord = Read-SpectreText -Message 'PSFzf tab-completion picker chord' -DefaultAnswer $s.Settings.FzfTabChord

        Write-PwshProfilePromptHelp @(
            'Print a **chord reference** once at the end of every startup — every keybinding this profile wires up (fzf''s pickers, `Initialize-PSReadline`''s bindings), plus a couple of related defaults that aren''t this module''s choice (**PSFzf**''s own `Alt+C`). Off by default; run `Show-PwshProfileChord` any time regardless.'
        ) -Accent $s.Accent -Code $s.Code
        $s.Settings.ShowChordGuidance = [bool](Read-SpectreConfirm -Message 'Show a keyboard-chord reference at every startup?' -Color $s.Accent -DefaultAnswer $(if ($s.Settings.ShowChordGuidance) { 'y' } else { 'n' }))
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
            -Body '**winget** is what installs the CLI tools below. This tunes the client itself — the defaults in its `settings.json` that apply whenever it installs a package. Applied once now; pre-filled from your current winget settings.'

        # Every package winget is about to handle -- git and oh-my-posh included, which is the reason
        # they are catalog rows now -- shown BEFORE the settings so they frame the question rather than
        # trailing it: the scope and progress-bar answers matter precisely because this is what they
        # will be applied to. Also the earliest point the plan can be seen, the install itself
        # happening after the review screen, by which time you have already committed.
        Show-PwshProfileInventory -Color $s.Accent

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

    # --- Step: PowerShell modules (disclosure only) -----------------------------------------
    $stepModules = {
        param($s, $i, $total)
        Write-PwshProfileStepHeader -Title 'Modules' -Index $i -Total $total -Accent $s.Accent -Code $s.Code `
            -Body 'The other half of what lands on your machine: a few **PowerShell Gallery** modules the profile leans on. Each installs for your user only (`CurrentUser` scope, no admin) the first time it is actually needed. Nothing to choose here — this step exists so it is not a surprise.'
        Show-PwshProfileInventory -Row (Get-PwshProfileModuleInventory) -Color $s.Accent
        # Every other step pauses on a prompt of its own; a step that only discloses has nothing to
        # ask, and without this the next step's header would scroll it away the instant it drew. The
        # answer is deliberately discarded -- -AllowEmpty makes a bare Enter the expected input.
        $null = Read-SpectreText -Message 'Press Enter to continue' -AllowEmpty
    }

    # Ordered step table — drives the forward pass and the review hub's Edit choices. Theme must stay
    # ahead of Banner and Step icon, which pre-fill from the branding it seeds.
    $steps = [ordered]@{
        'Fonts'        = $stepFonts
        'Winget'       = $stepWinget
        'Modules'      = $stepModules
        'Theme'        = $stepTheme
        'Banner'       = $stepBanner
        'Step icon'    = $stepIcon
        'Wiring'       = $stepWiring
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
        # Wiring summary, projected from the same catalog the tree renders — so a toggle cannot exist
        # in the tree and be silently missing from the review. Only the "on" side is listed; a row
        # left at Off contributes nothing rather than a noisy negative.
        $wiringParts = @(
            foreach ($row in Get-PwshProfileWiringCatalog) {
                if ($set.ContainsKey($row.Setting) -and $set[$row.Setting] -eq $row.On) {
                    "[$code]$(ConvertTo-EscapedText $row.Label)[/]"
                }
            }
            if ($set.FzfTabChord -and $set.FzfTabChord -ne 'Ctrl+Spacebar') {
                "[$code]tab: $(ConvertTo-EscapedText $set.FzfTabChord)[/]"
            }
            if ($set.ShowChordGuidance) {
                "[$code]chord guidance: on[/]"
            }
        )
        $featuresLine = if ($wiringParts.Count -gt 0) { $wiringParts -join " [grey]·[/] " }
        else { '[grey]nothing taken over[/]' }

        # What the install phase will actually do, so it isn't a surprise after Submit. Probed here
        # rather than carried in $Settings because the answer can change between passes through the
        # hub -- a tool could be installed in another window while the wizard is open.
        $inventory = @(Get-PwshProfileToolInventory)
        $toInstall = @($inventory | Where-Object { -not $_.Installed })
        $toolsLine = if ($toInstall.Count -eq 0) { "[grey]all $($inventory.Count) already installed[/]" }
        else { "[$code]$($toInstall.Count) to install[/] [grey]·[/] [grey]$($inventory.Count - $toInstall.Count) present[/]" }
        # The gallery modules are installed on demand by Import-ModuleSafe, not by setup, so this is
        # disclosure rather than a plan -- a conditional row may never be fetched at all.
        $modules = @(Get-PwshProfileModuleInventory)
        $modulesMissing = @($modules | Where-Object { -not $_.Installed })
        $modulesLine = if ($modulesMissing.Count -eq 0) { "[grey]all $($modules.Count) already installed[/]" }
        else { "[$code]$($modulesMissing.Count) to install[/] [grey]·[/] [grey]$($modules.Count - $modulesMissing.Count) present[/]" }
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
            "[bold]Wiring:[/]     $featuresLine"
            "[bold]Tools:[/]      $toolsLine"
            "[bold]Modules:[/]    $modulesLine"
            "[bold]bat:[/]        [$code]$(ConvertTo-EscapedText $set.BatTheme)[/] [grey]/[/] [$code]$(ConvertTo-EscapedText $set.BatStyle)[/]"
            "[bold]less:[/]       [$code]$(ConvertTo-EscapedText $set.LessOptions)[/]"
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
