function Initialize-PwshProfile {
    <#
    .SYNOPSIS
        Runs the Screw City profile startup: banner, shell config, prompt, tools, and completions.

    .DESCRIPTION
        Runs the whole profile startup as a single call:
          1. The startup banner (Write-Figlet), unless -NoBanner.
          2. "Core" (always renders): the `which` alias, git, PSReadLine, oh-my-posh, Terminal-Icons,
             posh-git, and the shell completions (winget, Azure CLI, Tailscale, Docker, 1Password,
             GitHub CLI — registration only; they detect external CLIs and install nothing).
          3. "WinGet" (only when at least one winget tool is enabled): zoxide, fzf, fnm, xh, jq, bat,
             fd, less, and lazygit. Order matters twice — git leads Core so it is on PATH for posh-git
             and lazygit, and fd follows fzf so it can wire fzf to use fd as its file source.

        The two groups mirror the install model: WinGet = the CLIs installed via WinGet, Core =
        everything else. Each is its own top-level Invoke-Step (status spinner + summary line). A step
        whose tool is missing degrades silently, so this never throws out of profile startup.

        Tool selection is opt-in. -Enable lists the tools to run; -EnableAll takes every current tool
        and auto-adopts future additions; a bare call asks first when interactive and enables nothing
        when not. -Enable wins if both are passed (a warning notes -EnableAll was ignored). git,
        oh-my-posh and the `which` alias always run and are not tokens. A tool-specific parameter for a
        tool that isn't enabled is warned about and ignored, never thrown.

        The theme drives more than the prompt. Unless set explicitly, it also supplies the banner color,
        the step icon, bat's syntax theme, fd's LS_COLORS palette, and fzf's picker palette, so every
        tool's colors blend with the prompt (screwcity -> Dracula/purple, forestcity -> gruvbox-dark/
        green). Banner *text* is not themed — it defaults to the machine name for every theme.

        Only the module's own startup runs here; anything else in your $PROFILE is left untouched.

    .PARAMETER BannerText
        Text rendered by the startup banner. Defaults to the machine name ($env:COMPUTERNAME) for every
        theme. Must be non-empty — to render no banner, use -NoBanner.

    .PARAMETER BannerColor
        Spectre color name or hex for the banner. Defaults to the selected theme's signature color.

    .PARAMETER BannerAlignment
        Banner alignment: 'Left' (default), 'Center', or 'Right'.

    .PARAMETER BannerFont
        A bundled FIGlet font for the banner (tab-completes), forwarded to Write-Figlet as -Font.
        Mutually exclusive with -BannerFontPath; Write-Figlet's default is used when neither is given.
        Run Show-FigletFont to list the bundled fonts, or Show-FigletFont -Preview to see samples.

    .PARAMETER BannerFontPath
        Path to a custom .flf FIGlet font, forwarded to Write-Figlet as -FontPath. Mutually exclusive
        with -BannerFont. Validated to exist at call time.

    .PARAMETER Theme
        The bundled oh-my-posh theme to use (tab-completes), default 'screwcity'. Resolved to its file
        under Assets/Themes and forwarded to Enable-OhMyPosh as -Configuration; it also seeds the
        branding described above. Mutually exclusive with -CustomTheme. Run Get-OhMyPoshTheme to dump a
        bundled theme's JSON as a starting point for your own.

    .PARAMETER CustomTheme
        Path to your own oh-my-posh theme file, used in place of a bundled theme. Validated to exist at
        call time, so a typo surfaces immediately rather than silently falling back to the bundle.
        Mutually exclusive with -Theme; branding falls back to the screwcity defaults.

    .PARAMETER ZoxideCommand
        The command name zoxide binds for jumping, forwarded to Enable-Zoxide as -Command. Defaults to
        'cd' (replacing the built-in); pass 'z' to keep cd intact.

    .PARAMETER BatTheme
        bat's syntax-highlighting theme (a value from `bat --list-themes`), forwarded to Enable-Bat as
        -Theme. Defaults to the selected theme's branding.

    .PARAMETER BatStyle
        bat's layout — a comma-separated component list forwarded to Enable-Bat as -Style. Defaults to
        'numbers,changes,header'.

    .PARAMETER ReplaceCat
        Alias cat -> bat for the session, replacing the built-in cat (an alias for Get-Content).
        Forwarded to Enable-Bat; off by default.

    .PARAMETER ReplaceMore
        Make less the pager: sets $env:PAGER (so `help`, bat, git, delta and gh page through less) and
        aliases more -> less. Forwarded to Enable-Less; off by default.

    .PARAMETER FdColors
        The LS_COLORS spec forwarded to Enable-Fd as -LsColors, so fd's output matches the prompt.
        Defaults to the selected theme's branding. Note LS_COLORS is shared with ls/eza.

    .PARAMETER FzfColors
        The fzf `--color` spec forwarded to Enable-Fzf as -Colors, so the picker matches the prompt.
        Defaults to the selected theme's branding.

    .PARAMETER StepIcon
        The marker printed before each top-level step, forwarded to Invoke-Step as -Icon. A Spectre
        emoji shortcode, e.g. ':nut_and_bolt:'. No trailing space — the separator is added at render
        time. Defaults to the selected theme's branding.

    .PARAMETER FzfGitKeyBindings
        Bind PSFzf's Ctrl+G git chords (fzf pickers for branches, commits, files). Off by default,
        since lazygit already covers git workflows. Only applies when Fzf is enabled (a warning notes
        it otherwise), and Enable-Fzf drops the chords anyway when git isn't on PATH.

    .PARAMETER FzfTabChord
        The PSReadLine chord for PSFzf's fuzzy tab-completion picker; Tab itself stays MenuComplete.
        Defaults to 'Ctrl+Spacebar', and Enable-Fzf also binds 'Ctrl+@' to the same picker (many
        terminals emit the same byte for both). Only applies when Fzf is enabled.

    .PARAMETER Enable
        The tools to enable, from the Get-PwshProfileToolCatalog set: 'PSReadLine', 'TerminalIcons',
        'PoshGit', 'Completions', 'Zoxide', 'Fzf', 'Fnm', 'Xh', 'Jq', 'Bat', 'Fd', 'Less', 'Lazygit'.
        Only the listed tools run, so a tool added in a later module version never installs until you
        add it here. Pass -Enable @() to enable nothing.

    .PARAMETER EnableAll
        Enable every tool in the catalog, including any added in future module versions. Convenient,
        but it opts into installing future tools with no prompt. -Enable wins if both are passed.

    .PARAMETER NoBanner
        Render no startup banner. Use this rather than clearing -BannerText, which rejects empty.
        Banner params passed alongside it are warned about and ignored.

    .EXAMPLE
        Initialize-PwshProfile

        A bare call has no tool selection: interactively it asks whether to enable all tools;
        non-interactively it enables none. Generated profiles always pass -Enable/-EnableAll.

    .EXAMPLE
        Initialize-PwshProfile -BannerText 'HELLO' -BannerColor Green -BannerAlignment Center

        Same startup with a centered green "HELLO" banner.

    .EXAMPLE
        Initialize-PwshProfile -BannerFont ANSIShadow

        Renders the startup banner in the bundled large ANSI Shadow block font.

    .EXAMPLE
        Initialize-PwshProfile -Theme forestcity

        Uses the bundled Forest City theme, with the banner and step marker branded to match.

    .EXAMPLE
        Initialize-PwshProfile -Enable Zoxide,Bat,Fd

        Enables only zoxide, bat, and fd (plus the always-on prompt, git, and `which`).

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
                # Completers run in the caller's scope, so reach the private lister through the module.
                $module = Get-Module ScrewCitySoftware.PwshProfile
                if ($module) {
                    & $module { Get-BundledThemeName } |
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
    #
    # The param -> tool coupling is the schema's Tool column, the same one gating what Build emits, so
    # the two cannot disagree about which tool owns a parameter. Note this reads the FULL schema, not
    # -Wizard: FdColors and FzfColors are runtime-only (never written to a profile) but are still
    # tool-owned parameters worth warning about.
    $settingSchema = Get-PwshProfileSettingSchema
    foreach ($row in $settingSchema | Where-Object Tool) {
        if ($PSBoundParameters.ContainsKey($row.Name) -and $enabled -notcontains $row.Tool) {
            Write-Warning "-$($row.Name) was supplied but $($row.Tool) is not enabled; ignoring -$($row.Name)."
        }
    }
    # Banner params are moot when no banner will render — either -NoBanner, or a banner text that
    # resolved empty (an unset $env:COMPUTERNAME), which is suppressed below rather than thrown.
    # Includes BannerFontPath, which Build never emits — the schema's Banner column covers every
    # banner parameter, and the Emit column is what separates the ones a profile can carry.
    $bannerParam = @(($settingSchema | Where-Object Banner).Name)
    $bannerIgnored = if ($NoBanner) { 'with -NoBanner; ignoring it (no banner is rendered)' }
    elseif ([string]::IsNullOrWhiteSpace($BannerText)) { 'but no banner text resolved (banner suppressed); ignoring it' }
    if ($bannerIgnored) {
        foreach ($p in $bannerParam) {
            if ($PSBoundParameters.ContainsKey($p)) { Write-Warning "-$p was supplied $bannerIgnored." }
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
    if ($enabled | Where-Object { $_ -in $wingetTokens }) {
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
