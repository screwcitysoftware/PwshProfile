function Initialize-PwshProfile {
    <#
    .SYNOPSIS
        Runs the default Screw City profile startup: banner, shell config, prompt, tools, and
        shell completions.

    .DESCRIPTION
        Reproduces the historical inline profile startup as a single call. In order it:
          1. Shows the startup banner (Write-Figlet).
          2. Runs "Shell": the `which` global alias and PSReadLine setup.
          3. Runs "Prompt": oh-my-posh, Terminal-Icons, and posh-git — oh-my-posh first, since
             it is the prompt engine and table stakes for this profile.
          4. Runs "Tools": zoxide, fzf, fnm, and xh — fzf sits next to zoxide (zoxide's
             interactive picker auto-uses fzf when it's on PATH), and fnm follows zoxide since
             Enable-FastNodeManager wraps zoxide's cd hook — then "Completions": winget,
             Azure CLI, Tailscale, Docker, and 1Password (registration only — these install nothing),
             since the completions are operations on the tools.

        Each of the three sections is its own top-level Invoke-Step, so each renders its own status
        spinner and a single summary line (Completions is a nested step under Tools). Steps that
        depend on a missing tool degrade silently (guarded by Get-Command / Import-ModuleSafe), so
        this never throws out of profile startup.

        Use -Theme to choose a bundled theme ('screwcity' or 'forestcity'), or -CustomTheme to point
        oh-my-posh at a theme file of your own (the two are mutually exclusive). The banner text
        defaults to the machine name ($env:COMPUTERNAME) regardless of theme; the bundled themes each
        carry a matching banner color and step marker — picking 'forestcity' defaults the banner to
        the theme's green with a 🌳 marker, while 'screwcity' keeps purple / 🔩 — applied only to the
        banner color/icon you don't set explicitly.
        Use -ZoxideCommand to rename zoxide's jump command, -StepIcon to rebrand the step marker,
        -Skip to opt out of individual tools (e.g. to avoid an unwanted winget auto-install), and
        -SkipSection to opt out of whole sections.

        It deliberately runs only the module's own startup — any other personal profile scripts you
        keep in $PROFILE are left untouched.

    .PARAMETER BannerText
        Text rendered by the startup banner. When omitted, defaults to the machine name
        ($env:COMPUTERNAME) for every theme. An empty or whitespace value renders no banner at all.

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

    .PARAMETER StepIcon
        The marker printed before each top-level step description, forwarded to Invoke-Step as
        -Icon. Defaults to ':nut_and_bolt:' (a Spectre emoji shortcode, rendered as 🔩). No trailing
        space is needed — the separator between the icon and the step text is added at render time.

    .PARAMETER Skip
        Individual tools to skip: 'Banner', 'PSReadLine', 'TerminalIcons', 'PoshGit', 'Zoxide',
        'Fzf', 'Fnm', 'Xh', 'Completions'. Dropping one omits its step; the auto-installing ones
        (Zoxide, Fzf, Fnm, Xh) thereby decline an unwanted winget install. 'Completions' drops the shell-completion
        registrations (winget, Azure CLI, Tailscale, Docker, 1Password, GitHub CLI) that run as the final Tools sub-step.
        oh-my-posh is table stakes for this profile and has no token in either parameter — it always
        runs. To skip whole sections, use -SkipSection.

    .PARAMETER SkipSection
        Whole sections to skip: 'Shell', 'Prompt', 'Tools'. Each drops the block and its summary
        line; skipping 'Tools' also drops the completions registered under it. 'Prompt' is special:
        because oh-my-posh is unskippable, passing it does NOT drop oh-my-posh — it drops only the
        cosmetic extras (Terminal-Icons + posh-git) and emits a warning explaining oh-my-posh was kept.

    .EXAMPLE
        Initialize-PwshProfile

        Runs the full default startup — equivalent to the former inline profile.

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
        Initialize-PwshProfile -CustomTheme '~/.config/themes/custom.omp.json' -Skip Fnm,Xh

        Uses a custom oh-my-posh theme and skips the fnm and xh steps (so neither is auto-installed).

    .EXAMPLE
        Initialize-PwshProfile -Skip Completions

        Runs startup but skips the shell-completion registrations (winget, Azure CLI, Tailscale,
        Docker, 1Password) under Tools.

    .NOTES
        Call from $PROFILE right after Import-Module of the manifest. The Completions step uses the
        per-tool enablers Enable-WingetCompletion, Enable-AzureCliCompletion, Enable-TailscaleCompletion,
        Enable-DockerCompletion, Enable-1PasswordCompletion, and Enable-GithubCliCompletion.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Bundled')]
    param(
        # Banner text defaults to the machine name; color/icon default to the selected theme's
        # branding. The empty-string sentinels are resolved in the body (banner text from
        # $env:COMPUTERNAME, color/icon from Get-BundledThemeBranding).
        [Parameter(Position = 0)]
        [string]$BannerText = '',

        [Parameter()]
        [string]$BannerColor = '',

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
                # Completers run in the caller's scope, where the module-private Get-BundledThemeName
                # is not visible — resolve the bundled themes from the loaded module's base path.
                $base = (Get-Module ScrewCitySoftware.PwshProfile).ModuleBase
                if ($base) {
                    Get-ChildItem -Path (Join-Path $base 'Assets' 'Themes') -Filter *.omp.json -ErrorAction SilentlyContinue |
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

        [Parameter()]
        [string]$StepIcon = '',

        [Parameter()]
        [ValidateSet('Banner', 'PSReadLine', 'TerminalIcons', 'PoshGit', 'Zoxide', 'Fzf', 'Fnm', 'Xh', 'Completions')]
        [string[]]$Skip = @(),

        [Parameter()]
        [ValidateSet('Shell', 'Prompt', 'Tools')]
        [string[]]$SkipSection = @()
    )

    # Resolve the oh-my-posh configuration and the matching banner branding from the chosen theme.
    # A custom theme has no bundled branding, so it falls back to the screwcity defaults ($Theme
    # keeps its 'screwcity' default value even in the Custom parameter set).
    if ($PSCmdlet.ParameterSetName -eq 'Custom') {
        $resolvedTheme = $CustomTheme
        $branding = Get-BundledThemeBranding -Name 'screwcity'
    }
    else {
        $resolvedTheme = Get-BundledThemePath -Name $Theme
        $branding = Get-BundledThemeBranding -Name $Theme
    }
    # Banner text defaults to the machine name for every theme; color/icon come from the theme branding.
    if (-not $PSBoundParameters.ContainsKey('BannerText'))  { $BannerText  = $env:COMPUTERNAME }
    if (-not $PSBoundParameters.ContainsKey('BannerColor')) { $BannerColor = $branding.BannerColor }
    if (-not $PSBoundParameters.ContainsKey('StepIcon'))    { $StepIcon    = $branding.StepIcon }

    if ($Skip -notcontains 'Banner' -and -not [string]::IsNullOrWhiteSpace($BannerText)) {
        # Forward the font only when supplied; -Font and -FontPath are mutually exclusive on
        # Write-Figlet, so pass at most one.
        $bannerFontArgs = @{}
        if ($PSBoundParameters.ContainsKey('BannerFont'))     { $bannerFontArgs.Font = $BannerFont }
        elseif ($PSBoundParameters.ContainsKey('BannerFontPath')) { $bannerFontArgs.FontPath = $BannerFontPath }

        Write-Figlet -Text $BannerText -Color $BannerColor -Alignment $BannerAlignment @bannerFontArgs
        # Write-Figlet no longer emits a trailing blank line; add the gap before the Shell step
        # (guarded like the rest of the module so a missing PwshSpectreConsole never throws).
        if (Get-Command Write-SpectreHost -ErrorAction SilentlyContinue) { Write-SpectreHost '' }
    }

    if ($SkipSection -notcontains 'Shell') {
        Invoke-Step "Shell" -Icon $StepIcon {
            Invoke-Step "Global Aliases" {
                Set-Alias -Name which -Value where.exe -Scope Global
            }
            if ($Skip -notcontains 'PSReadLine') {
                Invoke-Step "PSReadLine" {
                    Initialize-PSReadline
                }
            }
        }
    }

    # The Prompt block always runs — oh-my-posh is table stakes, has no skip token,
    # and initializes first. -SkipSection Prompt drops only the cosmetic extras
    # (Terminal-Icons + posh-git); warn so the user knows oh-my-posh was kept.
    if ($SkipSection -contains 'Prompt') {
        Write-Warning "oh-my-posh is core to this profile and cannot be skipped; -SkipSection Prompt drops only Terminal-Icons and posh-git. Use -Skip TerminalIcons,PoshGit to control those individually."
    }
    Invoke-Step "Prompt" -Icon $StepIcon {
        Invoke-Step "Oh-My-Posh" { Enable-OhMyPosh -Configuration $resolvedTheme }
        if ($Skip -notcontains 'TerminalIcons' -and $SkipSection -notcontains 'Prompt') { Invoke-Step "Terminal-Icons" { Import-ModuleSafe Terminal-Icons } }
        if ($Skip -notcontains 'PoshGit' -and $SkipSection -notcontains 'Prompt') { Invoke-Step "Posh-Git" { Import-ModuleSafe posh-git -Initialize { $env:POSH_GIT_ENABLED = $true } } }
    }

    if ($SkipSection -notcontains 'Tools') {
        Invoke-Step "Tools" -Icon $StepIcon {
            if ($Skip -notcontains 'Zoxide') { Invoke-Step "Zoxide" { Enable-Zoxide -Command $ZoxideCommand } }
            if ($Skip -notcontains 'Fzf')    { Invoke-Step "fzf" { Enable-Fzf } }
            if ($Skip -notcontains 'Fnm')    { Invoke-Step "Fast Node Manager (fnm)" { Enable-FastNodeManager } }
            if ($Skip -notcontains 'Xh')     { Invoke-Step "xh" { Enable-Xh } }
            # Shell completions are operations on the tools, so they register as the final Tools
            # sub-step (registration only — these install nothing). Skipped via -Skip Completions,
            # and dropped wholesale when the whole Tools section is skipped.
            if ($Skip -notcontains 'Completions') {
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
    }
}
