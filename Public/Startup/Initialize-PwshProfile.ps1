# Parameters this function used to accept and no longer does. Declared here, at file top outside the
# function (the same module-state shape Invoke-Step uses), so that "add the name here when you retire
# a parameter" is a findable instruction rather than folklore. Naming them buys a targeted message:
# a retired name means the caller's profile block is stale, which has a different fix from a typo.
$script:RetiredParameter = @('Enable', 'EnableAll')

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
          3. "WinGet": zoxide, fzf, fnm, xh, jq, bat, fd, ripgrep, less, lazygit, and uv. Order matters
             twice — git leads Core so it is on PATH for posh-git and lazygit, and fd follows fzf so
             it can wire fzf to use fd as its file source.

        The two groups mirror the install model: WinGet = the CLIs installed via WinGet, Core =
        everything else. Each is its own top-level Invoke-Step (status spinner + summary line). A step
        whose tool is missing degrades silently, so this never throws out of profile startup.

        Every tool runs — there is no tool selection. Install-PwshProfile installs the CLIs during
        setup, so at startup each Enable-* Install substep short-circuits on Get-Command and costs
        almost nothing; a tool that is genuinely missing (a fresh machine, or one added by a later
        module version) is installed here instead. What the wizard configures is how each tool is
        *wired* — which builtins it replaces, which chords it binds — not whether it is present.

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

    .PARAMETER LessOptions
        The option string assigned to $env:LESS, forwarded to Enable-Less as -Options. Defaults to
        '-R -F -i': raw color passthrough, quit-if-one-screen, and smart-case search.

    .PARAMETER SetPager
        Set $env:PAGER to less, so `help`, bat, git, delta and gh page through it. Forwarded to
        Enable-Less; off by default. Independent of -ReplaceMore.

    .PARAMETER ReplaceMore
        Alias more -> less. Forwarded to Enable-Less; off by default. Independent of -SetPager: this
        shadows the `more` command, that redirects programs which consult $env:PAGER (`help` invokes
        the literal string more.com, so the alias alone does not reach it).

    .PARAMETER ReplaceHttp
        Alias http -> xh and https -> xhs, widening each generated completer to match. Forwarded to
        Enable-Xh; off by default. Unlike cat and more these are not built-in commands, so this claims
        two free names rather than shadowing anything.

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
        Bind PSFzf's Ctrl+G,Ctrl+<key> git chords (fzf pickers for branches, files, hashes, pull
        requests, stashes, and tags). Off by default, since lazygit already covers git workflows.
        Enable-Fzf drops the chords when git isn't on PATH.

    .PARAMETER FzfTabChord
        The PSReadLine chord for PSFzf's fuzzy tab-completion picker; Tab itself stays MenuComplete.
        Defaults to 'Ctrl+Spacebar', and Enable-Fzf also binds 'Ctrl+@' to the same picker (many
        terminals emit the same byte for both).

    .PARAMETER ShowChordGuidance
        Print Show-PwshProfileChord once at the end of startup — every chord this profile actually
        wires up for this session (fzf's Ctrl+T/Ctrl+R/Ctrl+Spacebar always, Ctrl+G only when
        -FzfGitKeyBindings is on, Initialize-PSReadline's Up/Down/Tab/Alt+w/Alt+( always), plus a
        couple of related defaults that aren't this module's choice. Off by default;
        Show-PwshProfileChord runs standalone any time regardless.

    .PARAMETER NoBanner
        Render no startup banner. Use this rather than clearing -BannerText, which rejects empty.
        Banner params passed alongside it are warned about and ignored.

    .PARAMETER LegacyArgument
        Not passed directly. Collects any argument the parameter binder could not match, so that a
        retired parameter warns rather than throwing. A profile block written by an older version of
        the module — every one of them passed -Enable or -EnableAll, which no longer exist — would
        otherwise die on a ParameterBindingException before this function's body ran, leaving the
        shell with no prompt, no tools and no completions. Retired names get a message naming
        Install-PwshProfile; anything else is reported as a possible typo. Both are warnings, so
        startup always continues.

    .EXAMPLE
        Initialize-PwshProfile

        The whole startup with every default: the screwcity theme, a machine-name banner, and every
        tool wired with its default behavior. This is what a generated profile calls when nothing was
        customized.

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
        Initialize-PwshProfile -ReplaceCat -ZoxideCommand 'z'

        Aliases cat -> bat, and binds zoxide's jump to `z` so the built-in cd is left alone.

    .EXAMPLE
        Initialize-PwshProfile -CustomTheme '~/.config/themes/custom.omp.json' -NoBanner

        Uses a custom oh-my-posh theme and shows no banner.

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
        [string]$LessOptions = '-R -F -i',

        # Two independent halves of "make less the pager": $env:PAGER, and the `more` alias.
        [Parameter()]
        [switch]$SetPager,

        [Parameter()]
        [switch]$ReplaceMore,

        [Parameter()]
        [switch]$ReplaceHttp,

        # Unset sentinels; resolved in the body from the theme branding (like BatTheme).
        [Parameter()]
        [string]$FdColors,

        [Parameter()]
        [string]$FzfColors,

        [Parameter()]
        [string]$StepIcon,

        # Opt-in: lazygit already covers git.
        [Parameter()]
        [switch]$FzfGitKeyBindings,

        # Tab stays MenuComplete. Enable-Fzf also binds Ctrl+@ (same byte on many terminals).
        [Parameter()]
        [string]$FzfTabChord = 'Ctrl+Spacebar',

        # Off by default; the wizard surfaces this as an explicit question rather than a silent default.
        [Parameter()]
        [switch]$ShowChordGuidance,

        [Parameter()]
        [switch]$NoBanner,

        # Absorbs anything the binder can't match, so a profile block written by an older version of
        # the module warns instead of dying on a ParameterBindingException. Without this, a retired
        # parameter throws BEFORE the body runs -- no banner, no prompt, no tools, nothing -- which
        # is exactly the "never throw out of profile startup" rule this module is built on.
        [Parameter(ValueFromRemainingArguments)]
        [object[]]$LegacyArgument
    )

    # Report anything the binder could not match, then carry on. Guard on $null, NOT on .Count: with
    # no remaining arguments $LegacyArgument is $null, and $null.Count throws under
    # Set-StrictMode -Version Latest (which the suite and CI run), so the naive check would make this
    # shim the very thing it exists to prevent. @($null).Count is 1, so that is no use either.
    if ($null -ne $LegacyArgument) {
        $caught = @($LegacyArgument | Where-Object { $null -ne $_ } | ForEach-Object { "$_" })
        # A retired parameter arrives as its own element ('-Enable'), with any value following as a
        # separate one; only the flag-shaped elements are worth naming back to the user.
        $flags = @($caught | Where-Object { $_ -like '-*' } | ForEach-Object { $_.TrimStart('-') })
        $retired = @($flags | Where-Object { $_ -in $script:RetiredParameter })
        if ($retired.Count -gt 0) {
            Write-Warning ("Initialize-PwshProfile ignored retired parameter(s): -$($retired -join ', -'). " +
                'Your profile block was written by an older version of the module and every tool now ' +
                'runs regardless — run Install-PwshProfile to regenerate it.')
        }
        else {
            $shown = if ($flags.Count -gt 0) { @($flags | ForEach-Object { "-$_" }) } else { $caught }
            Write-Warning ("Initialize-PwshProfile ignored unrecognized argument(s): $($shown -join ', '). " +
                'Check for a typo, or run Install-PwshProfile to regenerate your profile block.')
        }
    }

    # Fresh slate for the startup-installed notice reported at the end: an earlier call in this
    # session that threw partway would otherwise leave entries behind for this one to re-report.
    $script:StartupInstall.Clear()

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

    # Banner params are moot when no banner will render — either -NoBanner, or a banner text that
    # resolved empty (an unset $env:COMPUTERNAME), which is suppressed below rather than thrown.
    # Includes BannerFontPath, which Build never emits — the schema's Banner column covers every
    # banner parameter, and the Emit column is what separates the ones a profile can carry. Reads the
    # FULL schema, not -Wizard, so the runtime-only BannerFontPath is covered.
    $bannerParam = @((Get-PwshProfileSettingSchema | Where-Object Banner).Name)
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

    # Core always renders, and so does every step in it -- there is nothing opt-in left. git and
    # oh-my-posh run HERE rather than in the WinGet section even though they are winget packages and
    # catalog rows: git has to be on PATH before posh-git and the git-aware WinGet tools, so the
    # catalog groups by install model while this orders by dependency. Only the `which` alias is
    # outside the catalog -- it installs nothing. PSReadLine runs before oh-my-posh, and PSFzf (WinGet
    # section, after Core) therefore initializes after it. Completions only register, so their
    # position is free.
    Invoke-Step "Core" -Icon $StepIcon {
        Invoke-Step "Global Aliases" {
            Set-Alias -Name which -Value where.exe -Scope Global
        }
        # Always-on, and first in Core so git is on PATH for posh-git and the WinGet-section tools.
        Invoke-Step "Git" { Enable-Git }
        Invoke-Step "PSReadLine" { Initialize-PSReadline }
        Invoke-Step "Oh-My-Posh" { Enable-OhMyPosh -Configuration $resolvedTheme }
        Invoke-Step "Terminal-Icons" { Import-ModuleSafe Terminal-Icons -Repair { Repair-TerminalIconsCache } }
        Invoke-Step "Posh-Git" { Import-ModuleSafe posh-git -Initialize { $env:POSH_GIT_ENABLED = $true } }
        Invoke-Step "Completions" {
            Invoke-Step "Winget Completions"    { Enable-WingetCompletion }
            Invoke-Step "Azure CLI Completions" { Enable-AzureCliCompletion }
            Invoke-Step "Tailscale Completions" { Enable-TailscaleCompletion }
            Invoke-Step "Docker Completions"    { Enable-DockerCompletion }
            Invoke-Step "1Password Completions" { Enable-1PasswordCompletion }
            Invoke-Step "GitHub CLI Completions" { Enable-GithubCliCompletion }
        }
    }

    Invoke-Step "WinGet" -Icon $StepIcon {
        Invoke-Step "Zoxide" { Enable-Zoxide -Command $ZoxideCommand }
        Invoke-Step "fzf" {
            # PSFzf supplies the Ctrl+T/Ctrl+R bindings (fzf ships none for PowerShell) and uses fd
            # for traversal. -GitKeyBindings is opt-in (lazygit covers git); Enable-Fzf drops it when
            # git isn't on PATH. -Height overrides PSFzf's inline 40% default with an adaptive one.
            # -TabExpansionChord leaves Tab as MenuComplete. The Ctrl+T preview is scoped to
            # $env:FZF_CTRL_T_OPTS by Enable-Fzf and inherits $env:BAT_THEME.
            Enable-Fzf -Colors $FzfColors -Style 'full' -Height '~100%' `
                -PreviewCommand 'bat --color=always --style=numbers {}' `
                -ProviderChord 'Ctrl+t' -HistoryChord 'Ctrl+r' -TabExpansionChord $FzfTabChord `
                -UseFd -GitKeyBindings:$FzfGitKeyBindings
        }
        Invoke-Step "Fast Node Manager (fnm)" { Enable-FastNodeManager }
        Invoke-Step "xh" { Enable-Xh -ReplaceHttp:$ReplaceHttp }
        Invoke-Step "jq" { Enable-Jq }
        Invoke-Step "bat" { Enable-Bat -Theme $BatTheme -Style $BatStyle -ReplaceCat:$ReplaceCat }
        # After fzf so fzf.exe is on PATH when -IntegrateFzf is evaluated.
        Invoke-Step "fd" { Enable-Fd -LsColors $FdColors -IntegrateFzf }
        # fd's content-search counterpart; no init-time dependency, so its position is free.
        Invoke-Step "ripgrep" { Enable-Ripgrep }
        # No init-time dependency on the other tools, so its position is free.
        Invoke-Step "less" { Enable-Less -Options $LessOptions -SetPager:$SetPager -ReplaceMore:$ReplaceMore }
        # Standalone git TUI: no shell init, no completion, no dependencies.
        Invoke-Step "lazygit" { Enable-Lazygit }
        # Standalone Python toolchain; no init-time dependency, so its position is free — kept last.
        Invoke-Step "uv" { Enable-Uv }
    }

    # Startup normally installs nothing: Install-PwshProfile did it, so every Install substep
    # short-circuits on Get-Command. When it DID install something -- a fresh machine, or a tool
    # added by a module update -- say so once, here, rather than per package. This sits after the
    # WinGet step so the spinner has cleared; a Write-Host inside a step would tear the render, which
    # is why the notice is a warning at all.
    if ($script:StartupInstall.Count -gt 0) {
        Write-Warning ("Installed $($script:StartupInstall -join ', ') during startup — this normally " +
            'happens during setup. Run Install-PwshProfile to install new tools ahead of time.')
    }

    # Sits after every Invoke-Step has cleared its spinner, same as the notice above -- a Format-*
    # render mid-step would tear it. Forwards the same fzf settings Enable-Fzf just wired up, so the
    # guidance reflects this session's actual configuration rather than a fresh-install default.
    if ($ShowChordGuidance) {
        Show-PwshProfileChord -FzfGitKeyBindings:$FzfGitKeyBindings -FzfTabChord $FzfTabChord
    }
}
