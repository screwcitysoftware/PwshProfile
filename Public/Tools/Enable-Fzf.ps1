function Enable-Fzf {
    <#
    .SYNOPSIS
        Installs (if necessary) fzf, themes it, and wires up its PowerShell key bindings (via PSFzf)
        for the session.

    .DESCRIPTION
        Runs two nested Invoke-Step substeps:
          - Install: if fzf.exe isn't on PATH, installs it with winget (junegunn.fzf, a
            portable package) and patches the current session's PATH so the exe is usable
            immediately.
          - Initialize (guarded by Get-Command fzf.exe):
              * Composes $env:FZF_DEFAULT_OPTS — the baseline for every fzf invocation (plain fzf,
                zoxide's `cdi`/`zi`, and PSFzf's widgets) — from "--ansi" plus "--style=<preset>"
                (when -Style is given) and "--color=<spec>" (when -Colors is given). It deliberately
                carries NO --preview, so directory pickers like zoxide's `cdi` stay clean. "--ansi"
                is always set as the baseline (it renders colored source output, e.g. Enable-Fd's
                `fd --color=always`, and is a no-op otherwise).
              * When -PreviewCommand is given, sets $env:FZF_CTRL_T_OPTS to "--preview '<command>'".
                PSFzf layers this on top of FZF_DEFAULT_OPTS for the Ctrl+T file picker only — so the
                bat preview shows for file searches but never for directory pickers. (Initialize-
                PwshProfile passes a `bat` command when bat is in play; bat inherits $env:BAT_THEME.)
              * When -Height is given, sets $env:_PSFZF_FZF_DEFAULT_OPTS (the base opts plus
                "--height=<value>"). PSFzf's PSReadLine widgets read that var in preference to
                FZF_DEFAULT_OPTS and otherwise force --height=40% (opening inline below the prompt);
                supplying our own --height both suppresses that default and sizes the pickers (100%
                fills the shell). FZF_DEFAULT_OPTS itself stays height-free, so a bare fzf and
                zoxide's `cdi` keep their native alternate-screen fullscreen.
              * fzf ships NO PowerShell key bindings, so when -ProviderChord / -HistoryChord / -UseFd
                / -GitKeyBindings is requested, it imports the PSFzf module (via Import-ModuleSafe)
                and calls Set-PsFzfOption to bind Ctrl+T (file picker) / Ctrl+R (fuzzy history), make
                PSFzf use fd for traversal (-EnableFd), and register the Ctrl+G fuzzy-git chords.
                PSReadLine must load before PSFzf — Initialize-PwshProfile's Shell step ensures that.

        If the install doesn't produce fzf.exe on PATH, a warning is emitted (with winget's
        captured output) and Initialize is skipped (guarded by Get-Command) so profile startup
        continues either way.

        fzf and zoxide are independent, standalone tools, but zoxide is built to integrate with
        fzf: when fzf.exe is on PATH, zoxide's interactive directory picker (`cdi` / `zi`)
        automatically uses fzf for fuzzy selection (and inherits the --color/--style set here).

    .PARAMETER Colors
        An fzf color spec (the value passed to fzf's `--color`, e.g.
        'hl:#5fd7ff,pointer:#c9aaff,prompt:#c9aaff'). When non-empty it is folded into
        $env:FZF_DEFAULT_OPTS as "--color=<spec>", so fzf's picker matches the prompt theme.
        Initialize-PwshProfile resolves this from the active theme's branding.

    .PARAMETER Style
        An fzf `--style` UI preset ('default', 'minimal', or 'full'). When non-empty it is folded
        into $env:FZF_DEFAULT_OPTS as "--style=<preset>". `--style` is an fzf 0.54+ feature, so it is
        applied only when the installed fzf is new enough (checked once via Get-FzfVersion) — a
        pre-existing older fzf that the install short-circuit didn't upgrade would otherwise fail on
        the unknown option. Initialize-PwshProfile passes 'full'.

    .PARAMETER Height
        An fzf `--height` value for the PSFzf PSReadLine widgets (Ctrl+T/Ctrl+R/git), e.g. '100%'
        (fills the entire shell), '~100%' (adaptive — shrinks to fit small result sets), or '40%'.
        When non-empty it is written, alongside the base opts, to $env:_PSFZF_FZF_DEFAULT_OPTS, which
        PSFzf reads in preference to $env:FZF_DEFAULT_OPTS. This overrides PSFzf's built-in
        --height=40% default (which opens the widgets inline below the prompt). Empty leaves that 40%
        default in place. Note: --height renders inline, not on the alternate screen, so it never
        perfectly matches a bare fzf's fullscreen — 100% is the closest. Initialize-PwshProfile passes
        '100%'.

    .PARAMETER PreviewCommand
        A command for the Ctrl+T file picker's `--preview` window, with `{}` standing in for the
        current line. When non-empty it is written to $env:FZF_CTRL_T_OPTS as "--preview '<command>'"
        — scoped to the Ctrl+T widget (PSFzf), NOT the global $env:FZF_DEFAULT_OPTS, so it never
        leaks into directory pickers like zoxide's `cdi`. Initialize-PwshProfile passes a `bat`
        command (when bat is in play) so files preview with syntax highlighting; bat inherits
        $env:BAT_THEME so the colors match the prompt.

    .PARAMETER ProviderChord
        The PSReadLine chord to bind to PSFzf's file/path picker (e.g. 'Ctrl+t'). When non-empty,
        PSFzf is installed/imported and the binding is registered. Empty leaves the chord unbound.

    .PARAMETER HistoryChord
        The PSReadLine chord to bind to PSFzf's fuzzy command-history search (e.g. 'Ctrl+r'). When
        non-empty, PSFzf is installed/imported and the binding is registered, overriding PSReadLine's
        native reverse-search on that chord. Empty leaves the chord unbound.

    .PARAMETER UseFd
        When set, calls Set-PsFzfOption -EnableFd so PSFzf uses fd for its file/directory traversal
        (Initialize-PwshProfile passes this when fd is in play). Set-PsFzfOption only records the
        option; fd is invoked later at Ctrl+T-time, by which point the fd step has installed it.

    .PARAMETER GitKeyBindings
        When set (and git is on PATH), calls Set-PsFzfOption -GitKeyBindings to register PSFzf's
        Ctrl+G,Ctrl+<key> fuzzy-git chord family (files, branches, hashes, tags, stashes). Guarded by
        Get-Command git so a git-less machine isn't left with dead Ctrl+G chords.

    .EXAMPLE
        Enable-Fzf

        Installs fzf if needed and sets $env:FZF_DEFAULT_OPTS to the baseline '--ansi' (so colored
        source output renders), leaving $env:FZF_CTRL_T_OPTS untouched and PSFzf uninstalled.

    .EXAMPLE
        Enable-Fzf -Colors 'hl:#5fd7ff,pointer:#c9aaff' -Style full -Height '100%' `
            -PreviewCommand 'bat --color=always --style=numbers {}' `
            -ProviderChord 'Ctrl+t' -HistoryChord 'Ctrl+r' -UseFd -GitKeyBindings

        Themes fzf (Screw City palette, full UI style), gives the Ctrl+T file picker a bat preview,
        and (via PSFzf) binds Ctrl+T / Ctrl+R fullscreen, uses fd for traversal, and adds the Ctrl+G
        git chords.

    .NOTES
        Standalone fuzzy finder (https://github.com/junegunn/fzf). fzf ships no PowerShell key
        bindings; the community PSFzf module (https://github.com/kelleyma49/PSFzf) supplies them,
        which is why the key-binding parameters install/import it. fzf owns its own options
        ($env:FZF_DEFAULT_OPTS / $env:FZF_CTRL_T_OPTS, plus $env:_PSFZF_FZF_DEFAULT_OPTS — PSFzf's
        widget-only override, used here to size the pickers via -Height); the "use fd as fzf's source"
        wiring ($env:FZF_DEFAULT_COMMAND) lives in Enable-Fd. The preview is Ctrl+T-scoped on purpose:
        zoxide's `cdi`/`zi` reads only FZF_DEFAULT_OPTS, so keeping the preview out of it leaves the
        directory picker clean.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Colors = '',

        [Parameter()]
        [string]$Style = '',

        [Parameter()]
        [string]$Height = '',

        [Parameter()]
        [string]$PreviewCommand = '',

        [Parameter()]
        [string]$ProviderChord = '',

        [Parameter()]
        [string]$HistoryChord = '',

        [Parameter()]
        [switch]$UseFd,

        [Parameter()]
        [switch]$GitKeyBindings
    )

    Invoke-Step "Install" {
        # fzf is a winget portable: its exe lands in the default Links dir.
        Install-WingetPackageSafe -Id 'junegunn.fzf' -Exe 'fzf.exe' -CallerName 'Enable-Fzf'
    }

    Invoke-Step "Initialize" {
        if (Get-Command fzf.exe -ErrorAction SilentlyContinue) {
            # Global baseline opts (read by EVERY fzf invocation, incl. zoxide's cdi): theme + style
            # only, NO --preview, so directory pickers stay clean. Plain assignment — env vars are
            # process-global. --ansi renders ANSI-colored source output (e.g. fd --color=always).
            $opts = [System.Collections.Generic.List[string]]::new()
            $opts.Add('--ansi')
            # --style is an fzf 0.54+ feature. The Install substep short-circuits when fzf.exe is
            # already on PATH, so it can't assume winget just supplied a current build — a pre-existing
            # older fzf would choke on --style and fail *every* fzf invocation (and zoxide's cdi). So
            # gate on the installed version (one `fzf --version` probe per session, via Get-FzfVersion,
            # and only when a -Style was actually requested); an undeterminable version ($null) is
            # treated as too-old and skips --style.
            if (-not [string]::IsNullOrWhiteSpace($Style)) {
                $fzfVersion = Get-FzfVersion
                if ($fzfVersion -and $fzfVersion -ge [version]'0.54') { $opts.Add("--style=$Style") }
            }
            if (-not [string]::IsNullOrWhiteSpace($Colors)) { $opts.Add("--color=$Colors") }

            # Always assign OPTS so --ansi is a guaranteed baseline: Enable-Fd's `fd --color=always`
            # source command relies on it to render colored output rather than raw escape codes, and
            # --ansi is a no-op when the input carries no color.
            $env:FZF_DEFAULT_OPTS = ($opts -join ' ')

            # PSFzf's PSReadLine widgets (Ctrl+T/Ctrl+R/git) force --height=40% unless the opts it
            # reads already carry a --height. PSFzf reads _PSFZF_FZF_DEFAULT_OPTS in preference to
            # FZF_DEFAULT_OPTS, so giving it its own opts (= the base + an explicit --height) both
            # suppresses that 40% default and sizes the pickers, while FZF_DEFAULT_OPTS stays
            # height-free → a bare fzf and zoxide's cdi keep their native alternate-screen fullscreen.
            if (-not [string]::IsNullOrWhiteSpace($Height)) {
                $env:_PSFZF_FZF_DEFAULT_OPTS = "$env:FZF_DEFAULT_OPTS --height=$Height"
            }

            # The bat preview is scoped to PSFzf's Ctrl+T file picker (FZF_CTRL_T_OPTS), never the
            # global opts — so it shows for file searches but not for directory pickers like cdi.
            if (-not [string]::IsNullOrWhiteSpace($PreviewCommand)) {
                $env:FZF_CTRL_T_OPTS = "--preview '$PreviewCommand'"
            }

            # fzf ships no PowerShell key bindings — PSFzf provides them. Build the option set first
            # (the Ctrl+G git chords only when git is present, so a git-less machine isn't left with
            # dead bindings), then install/import PSFzf and apply it only when something will actually
            # be set — so e.g. a lone -GitKeyBindings on a git-less box doesn't pull PSFzf in for nothing.
            $psfzf = @{}
            if (-not [string]::IsNullOrWhiteSpace($ProviderChord)) { $psfzf.PSReadlineChordProvider = $ProviderChord }
            if (-not [string]::IsNullOrWhiteSpace($HistoryChord))  { $psfzf.PSReadlineChordReverseHistory = $HistoryChord }
            if ($UseFd) { $psfzf.EnableFd = $true }
            if ($GitKeyBindings -and (Get-Command git -ErrorAction SilentlyContinue)) { $psfzf.GitKeyBindings = $true }
            if ($psfzf.Count -gt 0) {
                Import-ModuleSafe PSFzf
                if (Get-Command Set-PsFzfOption -ErrorAction SilentlyContinue) { Set-PsFzfOption @psfzf }
            }
        }
    }
}
