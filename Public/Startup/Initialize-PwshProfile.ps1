function Initialize-PwshProfile {
    <#
    .SYNOPSIS
        Runs the default Screw City profile startup: banner, shell config, prompt, tools, and
        shell completions.

    .DESCRIPTION
        Runs the profile startup as a single call. In order it:
          1. Shows the startup banner (Write-Figlet), unless -NoBanner.
          2. Runs "Core" (always): the `which` global alias, PSReadLine, oh-my-posh (the prompt engine,
             always on), Terminal-Icons, posh-git, and the shell completions (winget, Azure CLI,
             Tailscale, Docker, 1Password, GitHub CLI — registration only; they detect external CLIs and
             install nothing). Everything here except the `which` alias and oh-my-posh is opt-in.
          3. Runs "WinGet" (only when ≥1 winget tool is enabled): zoxide, fzf, fnm, xh, jq, bat, fd,
             less, and lazygit — the CLIs installed via WinGet. fzf sits next to zoxide (zoxide's
             interactive picker auto-uses fzf when on PATH); fnm registers a LocationChangedAction so
             it auto-switches the node version on any directory change (independent of zoxide and call
             order); fd follows fzf so it can wire fzf to use fd as its file source; less is bat's
             pager (and PowerShell's, via $env:PAGER); and lazygit is a standalone git TUI.

        The two groups mirror the install model: WinGet = tools installed via WinGet (opt-in), Core =
        everything else. Each is its own top-level Invoke-Step (its own status spinner + summary line).
        Steps that depend on a missing tool degrade silently (guarded by Get-Command / Import-ModuleSafe),
        so this never throws out of profile startup.

        Use -Theme to choose a bundled theme ('screwcity' or 'forestcity'), or -CustomTheme to point
        oh-my-posh at a theme file of your own (the two are mutually exclusive). The banner text
        defaults to the machine name ($env:COMPUTERNAME) regardless of theme; the bundled themes each
        carry a matching banner color and step marker — picking 'forestcity' defaults the banner to
        the theme's green with a 🌳 marker, while 'screwcity' keeps purple / 🔩 — applied only to the
        banner color/icon you don't set explicitly. The theme likewise seeds bat's syntax theme
        (-BatTheme), fd's LS_COLORS palette (-FdColors), and fzf's picker palette (-FzfColors) so
        those tools' colors blend with the prompt (screwcity -> Dracula/purple, forestcity ->
        gruvbox-dark/green). fzf also gets the `full` UI style and — via the PSFzf module — Ctrl+T
        (file picker, with a bat preview when bat is in play) and Ctrl+R (fuzzy history) key
        bindings, fd-backed traversal, and the Ctrl+G fuzzy-git chords (when git is present). Those
        PSFzf pickers are sized to fill the shell (--height=100%), overriding PSFzf's inline 40%
        default; a bare fzf and zoxide's `cdi` keep their native alternate-screen fullscreen.
        Tool selection is opt-in. Pass -Enable with the tools you want (e.g. -Enable Zoxide,Bat); only
        those run, so a tool added to the module in a later version never installs until you ask for it.
        Pass -EnableAll to enable every current tool and auto-adopt future additions. -Enable wins if
        both are given (the explicit list is the safer choice) and a warning notes -EnableAll was
        ignored. A bare call (neither, e.g. a hand-typed Initialize-PwshProfile) prompts before
        enabling everything when interactive, and enables nothing in a non-interactive session.
        oh-my-posh and the `which` alias always run; the banner is on by default and suppressed with
        -NoBanner. A tool-specific parameter (e.g. -ReplaceCat) for a tool that isn't enabled is warned
        about and ignored rather than throwing.

        Use -ZoxideCommand to rename zoxide's jump command, -StepIcon to rebrand the step marker,
        -BatTheme / -BatStyle to tune bat's appearance, -ReplaceCat to alias cat -> bat, -ReplaceMore
        to route the pager (more.com -> less) through $env:PAGER and alias more -> less, and -FdColors /
        -FzfColors to tune fd's and fzf's colors.

        It deliberately runs only the module's own startup — any other personal profile scripts you
        keep in $PROFILE are left untouched.

    .PARAMETER BannerText
        Text rendered by the startup banner. When omitted, defaults to the machine name
        ($env:COMPUTERNAME) for every theme. Must be non-empty — to render no banner, use -NoBanner.

    .PARAMETER BannerColor
        Spectre color name or hex for the banner. When omitted, defaults to the selected theme's
        signature color (screwcity's purple '#c9aaff' or forestcity's green '#8fce72').

    .PARAMETER BannerAlignment
        Banner alignment: 'Left', 'Center', or 'Right'. Defaults to 'Left'.

    .PARAMETER BannerFont
        A bundled FIGlet font for the banner (tab-completes), forwarded to Write-Figlet as -Font.
        Mutually exclusive with -BannerFontPath. When neither is given, Write-Figlet's default
        ('ANSIShadow') is used. Run Show-FigletFont to list the bundled fonts (or -Preview to see
        samples).

    .PARAMETER BannerFontPath
        Path to a custom .flf FIGlet font for the banner, forwarded to Write-Figlet as -FontPath.
        Mutually exclusive with -BannerFont. Validated to exist at call time.

    .PARAMETER Theme
        The bundled oh-my-posh theme to use (tab-completes): 'screwcity' (default) or 'forestcity'.
        Resolved to its file under Assets/Themes and forwarded to Enable-OhMyPosh as -Configuration.
        The choice also seeds the banner color and step icon for any you don't set explicitly (the
        banner text defaults to the machine name regardless of theme). Mutually exclusive with
        -CustomTheme. Run Get-OhMyPoshTheme to dump a bundled theme's JSON as a starting point for your own.

    .PARAMETER CustomTheme
        Path (relative or absolute) to a custom oh-my-posh theme file, forwarded to Enable-OhMyPosh
        as -Configuration in place of a bundled theme. The path is validated to exist at call time,
        so a typo surfaces immediately rather than silently falling back to the bundle. Mutually
        exclusive with -Theme; banner branding falls back to the screwcity defaults.

    .PARAMETER ZoxideCommand
        The command name zoxide binds for jumping, forwarded to Enable-Zoxide as -Command.
        Defaults to 'cd' (replacing the built-in cd); pass e.g. 'z' to keep cd intact.

    .PARAMETER BatTheme
        The bat syntax-highlighting theme, forwarded to Enable-Bat as -Theme (sets $env:BAT_THEME).
        When omitted, defaults to the selected theme's branding (screwcity's 'Dracula' or forestcity's
        'gruvbox-dark') so bat's colors blend with the prompt. A value from `bat --list-themes`.

    .PARAMETER BatStyle
        The bat layout, forwarded to Enable-Bat as -Style (sets $env:BAT_STYLE) — a comma-separated
        list of components. Defaults to 'numbers,changes,header'.

    .PARAMETER ReplaceCat
        Forwarded to Enable-Bat as -ReplaceCat: when set, aliases cat -> bat for the session (so the
        built-in cat, an alias for Get-Content, is replaced by bat). Off by default.

    .PARAMETER ReplaceMore
        Forwarded to Enable-Less as -ReplaceMore: when set, sets $env:PAGER to 'less' (so PowerShell's
        `help`, bat, git, delta, and gh page through less instead of more.com) and aliases more -> less
        for the session. Off by default.

    .PARAMETER FdColors
        The LS_COLORS spec, forwarded to Enable-Fd as -LsColors (sets $env:LS_COLORS) so fd's output
        is tinted to match the prompt. When omitted, defaults to the selected theme's branding
        (screwcity's purple-led palette or forestcity's green-led one). fd stays a standalone utility
        and never replaces Get-ChildItem. Note: LS_COLORS is shared with ls/eza.

    .PARAMETER FzfColors
        The fzf `--color` spec, forwarded to Enable-Fzf as -Colors (folded into $env:FZF_DEFAULT_OPTS)
        so fzf's picker palette matches the prompt. When omitted, defaults to the selected theme's
        branding (screwcity's purple/cyan or forestcity's green/gold).

    .PARAMETER StepIcon
        The marker printed before each top-level step description, forwarded to Invoke-Step as
        -Icon. Defaults to ':nut_and_bolt:' (a Spectre emoji shortcode, rendered as 🔩). No trailing
        space is needed — the separator between the icon and the step text is added at render time.

    .PARAMETER FzfGitKeyBindings
        Bind PSFzf's Ctrl+G git chords (fzf-powered pickers for branches, commits, files). Off by
        default (opt-in) — pass -FzfGitKeyBindings to enable them; they're off by default because
        lazygit already covers git workflows. Only applies when Fzf is enabled (a warning notes it
        otherwise); Enable-Fzf drops the chords regardless if git isn't on PATH.

    .PARAMETER FzfTabChord
        The PSReadLine chord that triggers PSFzf's fuzzy tab-completion picker (Tab itself stays
        MenuComplete). Defaults to 'Ctrl+Spacebar' — Enable-Fzf also binds 'Ctrl+@' to the same picker
        (many terminals emit the same byte for both and report it under either name). Only applies when
        Fzf is enabled (a warning notes it otherwise).

    .PARAMETER Enable
        The tools to enable (opt-in): any of 'PSReadLine', 'TerminalIcons', 'PoshGit', 'Zoxide', 'Fzf',
        'Fnm', 'Xh', 'Jq', 'Bat', 'Fd', 'Less', 'Lazygit', 'Completions'. Only the listed tools run (and the
        auto-installing ones install); everything else is skipped, so a tool added in a later module
        version never installs unless you add it here. Pass -Enable @() to enable nothing. The set mirrors
        Get-PwshProfileToolCatalog. oh-my-posh and the `which` alias always run and are not tokens.

    .PARAMETER EnableAll
        Enable every tool in the catalog, including any added in future module versions. Convenient but
        opts into auto-installing future tools. If both -EnableAll and -Enable are given, -Enable wins
        (the explicit list is the safer choice) and a warning notes -EnableAll was ignored.

    .PARAMETER NoBanner
        Render no startup banner. Use this to suppress the banner instead of clearing -BannerText (which
        rejects empty). Passing banner params (e.g. -BannerColor) alongside -NoBanner warns and ignores them.

    .EXAMPLE
        Initialize-PwshProfile

        A bare call has no tool selection: interactively it asks whether to enable all tools;
        non-interactively it enables none. Generated profiles pass -Enable/-EnableAll, so they never prompt.

    .EXAMPLE
        Initialize-PwshProfile -BannerText 'HELLO' -BannerColor Green -BannerAlignment Center

        Same startup with a centered green "HELLO" banner.

    .EXAMPLE
        Initialize-PwshProfile -BannerFont ANSIShadow

        Renders the startup banner in the bundled large ANSI Shadow block font.

    .EXAMPLE
        Initialize-PwshProfile -Theme forestcity

        Uses the bundled Forest City theme, with the machine-name banner in the theme's green and a 🌳
        step marker applied automatically.

    .EXAMPLE
        Initialize-PwshProfile -Enable Zoxide,Bat,Fd

        Enables only zoxide, bat, and fd (plus the always-on prompt and `which`); no other tool installs.

    .EXAMPLE
        Initialize-PwshProfile -CustomTheme '~/.config/themes/custom.omp.json' -EnableAll -NoBanner

        Uses a custom oh-my-posh theme, enables every tool (and future additions), and shows no banner.

    .NOTES
        Call from $PROFILE right after Import-Module of the manifest. The Completions step uses the
        per-tool enablers Enable-WingetCompletion, Enable-AzureCliCompletion, Enable-TailscaleCompletion,
        Enable-DockerCompletion, Enable-1PasswordCompletion, and Enable-GithubCliCompletion.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Bundled')]
    param(
        # Color/icon are unset by default and resolved in the body from the theme branding.
        # BannerText has a real default and rejects empty — use -NoBanner to suppress the banner.
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$BannerText = $env:COMPUTERNAME,

        [Parameter()]
        [string]$BannerColor,

        [Parameter()]
        [ValidateSet('Left', 'Center', 'Right')]
        [string]$BannerAlignment = 'Left',

        [Parameter()]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                # Completers run in the caller's scope; Show-FigletFont (no args) lists the names.
                Show-FigletFont | Where-Object { $_ -like "$wordToComplete*" } |
                    ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
            })]
        [ValidateScript({ $_ -in (Get-BundledFontName) },
            ErrorMessage = "'{0}' is not a bundled font. Run Show-FigletFont to list the available fonts.")]
        [string]$BannerFont,

        [Parameter()]
        [ValidateScript({
                [string]::IsNullOrWhiteSpace($_) -or (Test-Path -Path $_) },
            ErrorMessage = "BannerFontPath '{0}' does not exist (expected a path to a .flf FIGlet font file).")]
        [string]$BannerFontPath,

        [Parameter(ParameterSetName = 'Bundled')]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                # Completers run in the caller's scope, where Get-BundledThemeName isn't visible.
                $base = (Get-Module ScrewCitySoftware.PwshProfile).ModuleBase
                if ($base) {
                    Get-ChildItem -Path (Join-Path -Path $base -ChildPath 'Assets\Themes') -Filter *.omp.json -ErrorAction SilentlyContinue |
                        ForEach-Object { $_.Name -replace '\.omp\.json$', '' } |
                        Where-Object { $_ -like "$wordToComplete*" } |
                        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
                }
            })]
        [ValidateScript({ $_ -in (Get-BundledThemeName) },
            ErrorMessage = "'{0}' is not a bundled theme. Run Get-OhMyPoshTheme or check Assets/Themes for the available themes.")]
        [string]$Theme = 'screwcity',

        [Parameter(Mandatory, ParameterSetName = 'Custom')]
        [ValidateScript({ Test-Path -Path $_ },
            ErrorMessage = "CustomTheme path '{0}' does not exist (expected a relative or absolute path to an .omp.json).")]
        [string]$CustomTheme,

        [Parameter()]
        [string]$ZoxideCommand = 'cd',

        # Unset sentinel; resolved in the body from the theme branding (like BannerColor).
        [Parameter()]
        [string]$BatTheme,

        [Parameter()]
        [string]$BatStyle = 'numbers,changes,header',

        [Parameter()]
        [switch]$ReplaceCat,

        [Parameter()]
        [switch]$ReplaceMore,

        # Unset sentinels; resolved in the body from the theme branding (like BatTheme).
        [Parameter()]
        [string]$FdColors,

        [Parameter()]
        [string]$FzfColors,

        [Parameter()]
        [string]$StepIcon,

        # Opt-in: lazygit already covers git. Only applies when Fzf is enabled.
        [Parameter()]
        [switch]$FzfGitKeyBindings,

        # Tab stays MenuComplete. Enable-Fzf also binds Ctrl+@ (same byte on many terminals).
        [Parameter()]
        [string]$FzfTabChord = 'Ctrl+Spacebar',

        # ValidateSet mirrors Get-PwshProfileToolCatalog -Token; Tests/ToolCatalog.Tests.ps1 keeps them
        # in sync. No default, so PSBoundParameters separates "passed empty" from "not passed".
        [Parameter()]
        [ValidateSet('PSReadLine', 'TerminalIcons', 'PoshGit', 'Completions', 'Zoxide', 'Fzf', 'Fnm', 'Xh', 'Jq', 'Bat', 'Fd', 'Less', 'Lazygit')]
        [string[]]$Enable,

        [Parameter()]
        [switch]$EnableAll,

        [Parameter()]
        [switch]$NoBanner
    )

    # Resolve the oh-my-posh config and matching branding. A custom theme has no bundled branding, so
    # it falls back to screwcity ($Theme keeps its default even in the Custom parameter set).
    if ($PSCmdlet.ParameterSetName -eq 'Custom') {
        $resolvedTheme = $CustomTheme
        $branding = Get-BundledThemeBranding -Name 'screwcity'
    }
    else {
        $resolvedTheme = Get-BundledThemePath -Name $Theme
        $branding = Get-BundledThemeBranding -Name $Theme
    }
    # Color/icon come from the theme branding when not set explicitly (BannerText has a real default).
    if (-not $PSBoundParameters.ContainsKey('BannerColor')) { $BannerColor = $branding.BannerColor }
    if (-not $PSBoundParameters.ContainsKey('StepIcon'))    { $StepIcon    = $branding.StepIcon }
    # bat's syntax theme follows the prompt theme unless set explicitly (screwcity -> Dracula, etc.).
    if (-not $PSBoundParameters.ContainsKey('BatTheme'))    { $BatTheme    = $branding.BatTheme }
    # fd's and fzf's color palettes likewise follow the prompt theme unless set explicitly.
    if (-not $PSBoundParameters.ContainsKey('FdColors'))    { $FdColors    = $branding.LsColors }
    if (-not $PSBoundParameters.ContainsKey('FzfColors'))   { $FzfColors   = $branding.FzfColors }

    # -Enable wins over -EnableAll (the explicit list is the safer choice); a bare call asks first.
    # Runs before any Invoke-Step, so warnings land in scrollback instead of tearing a live spinner.
    $catalog = Get-PwshProfileToolCatalog -Token
    $hasEnable = $PSBoundParameters.ContainsKey('Enable')
    if ($hasEnable -and $EnableAll) {
        Write-Warning '-Enable and -EnableAll were both supplied; -EnableAll is ignored in favor of the explicit -Enable list.'
    }
    $enabled = if ($hasEnable) { @($Enable) }
               elseif ($EnableAll) { @($catalog) }
               else { if (Confirm-PwshProfileEnableAll -Catalog $catalog) { @($catalog) } else { @() } }

    # A flag for a tool that isn't enabled is a no-op, so warn rather than throw or silently ignore.
    # Build-PwshProfileInitializeCall only emits these for enabled tools, so only hand-edits trip it.
    $paramTool = [ordered]@{
        ZoxideCommand = 'Zoxide'; BatTheme = 'Bat'; BatStyle = 'Bat'; ReplaceCat = 'Bat'
        ReplaceMore = 'Less'; FdColors = 'Fd'; FzfColors = 'Fzf'
        FzfGitKeyBindings = 'Fzf'; FzfTabChord = 'Fzf'
    }
    foreach ($p in $paramTool.Keys) {
        if ($PSBoundParameters.ContainsKey($p) -and $enabled -notcontains $paramTool[$p]) {
            Write-Warning "-$p was supplied but $($paramTool[$p]) is not enabled; ignoring -$p."
        }
    }
    # Banner coupling: the banner params are moot under -NoBanner.
    if ($NoBanner) {
        foreach ($p in 'BannerText', 'BannerColor', 'BannerAlignment', 'BannerFont', 'BannerFontPath') {
            if ($PSBoundParameters.ContainsKey($p)) { Write-Warning "-$p was supplied with -NoBanner; ignoring it (no banner is rendered)." }
        }
    }

    # [ValidateNotNullOrEmpty()] guards an explicit value but not the $env:COMPUTERNAME default, so
    # re-check: an unset COMPUTERNAME would otherwise throw out of Write-Figlet's Mandatory -Text.
    if (-not $NoBanner -and -not [string]::IsNullOrWhiteSpace($BannerText)) {
        # -Font and -FontPath are mutually exclusive on Write-Figlet, so pass at most one.
        $bannerFontArgs = @{}
        if ($PSBoundParameters.ContainsKey('BannerFont'))     { $bannerFontArgs.Font = $BannerFont }
        elseif ($PSBoundParameters.ContainsKey('BannerFontPath')) { $bannerFontArgs.FontPath = $BannerFontPath }

        Write-Figlet -Text $BannerText -Color $BannerColor -Alignment $BannerAlignment @bannerFontArgs
        # Write-Figlet emits no trailing blank line, so add the gap before the first step.
        if (Get-Command Write-SpectreHost -ErrorAction SilentlyContinue) { Write-SpectreHost '' }
    }
    elseif (-not $NoBanner) {
        # Banner suppressed because the text resolved empty. Warn for any bound banner param so the
        # silent drop is visible, matching the -NoBanner coupling warnings above.
        foreach ($p in 'BannerText', 'BannerColor', 'BannerAlignment', 'BannerFont', 'BannerFontPath') {
            if ($PSBoundParameters.ContainsKey($p)) { Write-Warning "-$p was supplied but no banner text resolved (banner suppressed); ignoring it." }
        }
    }

    # Core always renders. oh-my-posh, git and the `which` alias are always-on (not catalog tokens);
    # the rest are opt-in. PSReadLine runs before oh-my-posh, and PSFzf (WinGet section, after Core)
    # therefore initializes after it. Completions only register, so their position is free.
    Invoke-Step "Core" -Icon $StepIcon {
        Invoke-Step "Global Aliases" {
            Set-Alias -Name which -Value where.exe -Scope Global
        }
        # Always-on, and first in Core so git is on PATH for posh-git and the WinGet-section tools.
        Invoke-Step "Git" { Enable-Git }
        if ($enabled -contains 'PSReadLine') { Invoke-Step "PSReadLine" { Initialize-PSReadline } }
        Invoke-Step "Oh-My-Posh" { Enable-OhMyPosh -Configuration $resolvedTheme }
        if ($enabled -contains 'TerminalIcons') { Invoke-Step "Terminal-Icons" { Import-ModuleSafe Terminal-Icons -Repair { Repair-TerminalIconsCache } } }
        if ($enabled -contains 'PoshGit') { Invoke-Step "Posh-Git" { Import-ModuleSafe posh-git -Initialize { $env:POSH_GIT_ENABLED = $true } } }
        if ($enabled -contains 'Completions') {
            Invoke-Step "Completions" {
                Invoke-Step "Winget Completions"    { Enable-WingetCompletion }
                Invoke-Step "Azure CLI Completions" { Enable-AzureCliCompletion }
                Invoke-Step "Tailscale Completions" { Enable-TailscaleCompletion }
                Invoke-Step "Docker Completions"    { Enable-DockerCompletion }
                Invoke-Step "1Password Completions" { Enable-1PasswordCompletion }
                Invoke-Step "GitHub CLI Completions" { Enable-GithubCliCompletion }
            }
        }
    }

    # Rendered only when a winget tool is enabled, so it is never an empty section. The token set is
    # the catalog's WinGet group (Install -eq 'winget'), not a hardcoded list.
    $wingetTokens = @((Get-PwshProfileToolCatalog)['WinGet'].Token)
    if (@($enabled | Where-Object { $wingetTokens -contains $_ }).Count) {
        Invoke-Step "WinGet" -Icon $StepIcon {
            if ($enabled -contains 'Zoxide') { Invoke-Step "Zoxide" { Enable-Zoxide -Command $ZoxideCommand } }
            if ($enabled -contains 'Fzf') {
                Invoke-Step "fzf" {
                    # Preview with bat only when bat is enabled; it inherits $env:BAT_THEME.
                    $fzfPreview = if ($enabled -contains 'Bat') { 'bat --color=always --style=numbers {}' } else { '' }
                    # PSFzf supplies the Ctrl+T/Ctrl+R bindings (fzf ships none for PowerShell) and
                    # uses fd for traversal. -GitKeyBindings is opt-in (lazygit covers git); Enable-Fzf
                    # drops it when git isn't on PATH. -Height overrides PSFzf's inline 40% default with
                    # an adaptive one. -TabExpansionChord leaves Tab as MenuComplete.
                    Enable-Fzf -Colors $FzfColors -Style 'full' -Height '~100%' -PreviewCommand $fzfPreview `
                        -ProviderChord 'Ctrl+t' -HistoryChord 'Ctrl+r' -TabExpansionChord $FzfTabChord `
                        -UseFd:($enabled -contains 'Fd') -GitKeyBindings:$FzfGitKeyBindings
                }
            }
            if ($enabled -contains 'Fnm')    { Invoke-Step "Fast Node Manager (fnm)" { Enable-FastNodeManager } }
            if ($enabled -contains 'Xh')     { Invoke-Step "xh" { Enable-Xh } }
            if ($enabled -contains 'Jq')     { Invoke-Step "jq" { Enable-Jq } }
            if ($enabled -contains 'Bat')    { Invoke-Step "bat" { Enable-Bat -Theme $BatTheme -Style $BatStyle -ReplaceCat:$ReplaceCat } }
            # After fzf so fzf.exe is on PATH when -IntegrateFzf is evaluated.
            if ($enabled -contains 'Fd')     { Invoke-Step "fd" { Enable-Fd -LsColors $FdColors -IntegrateFzf:($enabled -contains 'Fzf') } }
            # No init-time dependency on the other tools, so its position is free.
            if ($enabled -contains 'Less')   { Invoke-Step "less" { Enable-Less -ReplaceMore:$ReplaceMore } }
            # Standalone git TUI: no shell init, no completion, no dependencies — kept last.
            if ($enabled -contains 'Lazygit') { Invoke-Step "lazygit" { Enable-Lazygit } }
        }
    }
}
