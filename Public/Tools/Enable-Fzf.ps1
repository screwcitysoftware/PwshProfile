function Enable-Fzf {
    <#
    .SYNOPSIS
        Installs (if necessary) fzf, themes it, and wires up its PowerShell key bindings via PSFzf.

    .DESCRIPTION
        Runs two nested Invoke-Step substeps:
          - Install: if fzf.exe isn't on PATH, installs junegunn.fzf with winget and patches the
            current session's PATH so the exe is usable immediately.
          - Initialize (guarded by Test-CommandAvailable): composes the environment variables fzf and
            PSFzf read, then binds the key chords.

        $env:FZF_DEFAULT_OPTS is the baseline every fzf invocation sees — plain fzf, zoxide's
        `cdi`/`zi`, and PSFzf's widgets. It always carries "--ansi" (so colored source output such as
        Enable-Fd's `fd --color=always` renders) and "--ignore-case" (fzf defaults to smart-case, but
        PowerShell/Windows is case-insensitive), plus -Style and -Colors when given. It deliberately
        carries no --preview, so directory pickers stay clean.

        -PreviewCommand and -Height are scoped narrowly on purpose. The preview goes to
        $env:FZF_CTRL_T_OPTS, so it shows for the Ctrl+T file picker but never for a directory picker.
        The height goes to $env:_PSFZF_FZF_DEFAULT_OPTS, which PSFzf's widgets read in preference to
        FZF_DEFAULT_OPTS; supplying a --height there both suppresses PSFzf's inline 40% default and
        sizes the pickers, while FZF_DEFAULT_OPTS stays height-free so a bare fzf and zoxide's `cdi`
        keep their native alternate-screen fullscreen.

        fzf ships no PowerShell key bindings, so the chord parameters import PSFzf (via
        Import-ModuleSafe) and call Set-PsFzfOption. PSReadLine must load first — Initialize-PwshProfile
        orders that. If the install doesn't produce fzf.exe on PATH, a warning is emitted and Initialize
        is skipped, so profile startup continues either way.

    .PARAMETER Colors
        An fzf color spec (the value for fzf's `--color`), folded into $env:FZF_DEFAULT_OPTS so the
        picker matches the prompt theme. Initialize-PwshProfile resolves this from the theme branding.

    .PARAMETER Style
        An fzf `--style` UI preset: 'default', 'minimal', or 'full'. Applied only when the installed
        fzf is 0.54+ (checked once via Get-FzfVersion) — the install short-circuits on an existing
        fzf.exe, and an older build would fail on the unknown option.

    .PARAMETER Height
        An fzf `--height` for the PSFzf widgets, e.g. '100%' or '~100%' (adaptive — shrinks to fit
        small result sets). Written to $env:_PSFZF_FZF_DEFAULT_OPTS, overriding PSFzf's --height=40%
        default; empty leaves that default in place. --height renders inline rather than on the
        alternate screen, so it never quite matches a bare fzf's fullscreen.

    .PARAMETER PreviewCommand
        A command for the Ctrl+T picker's `--preview` window, with `{}` standing in for the current
        line. Written to $env:FZF_CTRL_T_OPTS. Initialize-PwshProfile passes a `bat` command when bat
        is in play; bat inherits $env:BAT_THEME so the preview matches the prompt.

    .PARAMETER ProviderChord
        The PSReadLine chord for PSFzf's file/path picker (e.g. 'Ctrl+t'). Empty leaves it unbound.

    .PARAMETER HistoryChord
        The PSReadLine chord for PSFzf's fuzzy history search (e.g. 'Ctrl+r'), overriding PSReadLine's
        native reverse-search on that chord. Empty leaves it unbound.

    .PARAMETER TabExpansionChord
        A PSReadLine chord bound to PSFzf's Invoke-FzfTabCompletion, opening a fuzzy picker over
        PowerShell's native completion candidates — paths, cmdlet/parameter names, and every registered
        argument completer. A single candidate inserts directly. Tab is left as MenuComplete:
        Set-PsFzfOption -TabExpansion only ever targets Tab, which is why this binds the function
        directly. Passing 'Ctrl+Spacebar' or 'Ctrl+@' binds both, since many terminals emit the same
        byte (NUL) for the two and PSReadLine may report either name. Empty leaves it unbound.

    .PARAMETER UseFd
        Calls Set-PsFzfOption -EnableFd so PSFzf uses fd for its own traversal. In practice this
        governs only PSFzf's directory lookup (Alt+C) — Ctrl+T prefers $env:FZF_DEFAULT_COMMAND, and
        Enable-Fd sets both that and $env:FZF_ALT_C_COMMAND. fd is invoked later, at key-press time.

    .PARAMETER GitKeyBindings
        Registers PSFzf's Ctrl+G,Ctrl+<key> fuzzy-git chords (files, branches, hashes, tags, stashes).
        Guarded by Test-CommandAvailable so a git-less machine isn't left with dead chords.

    .EXAMPLE
        Enable-Fzf

        Installs fzf if needed and sets the baseline opts, leaving PSFzf uninstalled and no chords bound.

    .EXAMPLE
        Enable-Fzf -Colors 'hl:#5fd7ff,pointer:#c9aaff' -Style full -Height '~100%' `
            -PreviewCommand 'bat --color=always --style=numbers {}' `
            -ProviderChord 'Ctrl+t' -HistoryChord 'Ctrl+r' -TabExpansionChord 'Ctrl+Spacebar' `
            -UseFd -GitKeyBindings

        Themes fzf, gives the Ctrl+T picker a bat preview, and binds the full PSFzf chord set.

    .NOTES
        Standalone fuzzy finder (https://github.com/junegunn/fzf). The key bindings come from the
        community PSFzf module (https://github.com/kelleyma49/PSFzf), which is why the chord parameters
        install it. fzf owns its own options here; the "use fd as fzf's source" wiring lives in
        Enable-Fd.

        PSFzf double-quotes any completion candidate containing whitespace — including the trailing
        "this token is complete" space that argcomplete (`az`), Cobra CLIs in MenuComplete mode
        (`gh`/`tailscale`/`op`), and winget append, so those would insert as `"account "`. After
        importing PSFzf this calls Repair-PsFzfCompletionQuoting to trim that trailing space.
        Completers that emit no trailing space were already fine and are unaffected.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Colors,

        [Parameter()]
        [string]$Style,

        [Parameter()]
        [string]$Height,

        [Parameter()]
        [string]$PreviewCommand,

        [Parameter()]
        [string]$ProviderChord,

        [Parameter()]
        [string]$HistoryChord,

        [Parameter()]
        [string]$TabExpansionChord,

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
        if (Test-CommandAvailable -Name 'fzf.exe') {
            # Global baseline opts, read by EVERY fzf invocation including zoxide's cdi: theme + style
            # only, no --preview, so directory pickers stay clean. --ansi renders colored source output.
            $opts = [System.Collections.Generic.List[string]]::new()
            $opts.Add('--ansi')
            # Force case-insensitive: fzf defaults to smart-case, but PowerShell/Windows isn't. Governs
            # every fzf surface (bare fzf, PSFzf widgets, cdi, git chords) — fzf does the matching, not fd.
            $opts.Add('--ignore-case')
            # --style needs fzf 0.54+. The Install substep short-circuits on an existing fzf.exe, so a
            # pre-existing older build would choke on --style and break every fzf call. Gate on the
            # probed version (Get-FzfVersion, once per session); an unknown version counts as too old.
            if (-not [string]::IsNullOrWhiteSpace($Style)) {
                $fzfVersion = Get-FzfVersion
                if ($fzfVersion -and $fzfVersion -ge [version]'0.54') { $opts.Add("--style=$Style") }
            }
            if (-not [string]::IsNullOrWhiteSpace($Colors)) { $opts.Add("--color=$Colors") }

            # Assign unconditionally so --ansi is a guaranteed baseline: Enable-Fd's `fd --color=always`
            # relies on it, and --ansi is a no-op when the input carries no color.
            $env:FZF_DEFAULT_OPTS = ($opts -join ' ')

            # PSFzf's widgets force --height=40% unless the opts they read already carry a --height, and
            # PSFzf reads _PSFZF_FZF_DEFAULT_OPTS in preference to FZF_DEFAULT_OPTS. Giving it its own
            # opts sizes the pickers while FZF_DEFAULT_OPTS stays height-free, so a bare fzf and cdi keep
            # their native fullscreen. Unconditional, so a reload that drops -Height clears the old value.
            $env:_PSFZF_FZF_DEFAULT_OPTS = if (-not [string]::IsNullOrWhiteSpace($Height)) {
                "$env:FZF_DEFAULT_OPTS --height=$Height"
            }
            else { $env:FZF_DEFAULT_OPTS }

            # Scoped to PSFzf's Ctrl+T file picker, never the global opts, so it shows for file searches
            # but not directory pickers like cdi. Unconditional, so a reload clears a stale preview.
            $env:FZF_CTRL_T_OPTS = if (-not [string]::IsNullOrWhiteSpace($PreviewCommand)) {
                "--preview '$PreviewCommand'"
            }
            else { '' }

            # fzf ships no PowerShell key bindings — PSFzf provides them. Build the option set first (git
            # chords only when git is present, so a git-less box isn't left with dead bindings), then pull
            # PSFzf in only if something will actually be set.
            $psfzf = @{}
            if (-not [string]::IsNullOrWhiteSpace($ProviderChord)) { $psfzf.PSReadlineChordProvider = $ProviderChord }
            if (-not [string]::IsNullOrWhiteSpace($HistoryChord))  { $psfzf.PSReadlineChordReverseHistory = $HistoryChord }
            if ($UseFd) { $psfzf.EnableFd = $true }
            if ($GitKeyBindings -and (Test-CommandAvailable -Name 'git')) { $psfzf.GitKeyBindings = $true }
            # -TabExpansionChord needs PSFzf too, so fold it into the "do we need PSFzf?" decision.
            $needPsfzf = $psfzf.Count -gt 0 -or -not [string]::IsNullOrWhiteSpace($TabExpansionChord)
            if ($needPsfzf) {
                Import-ModuleSafe PSFzf
                # PSFzf double-quotes any candidate containing whitespace — including the trailing space
                # that argcomplete, Cobra, and winget append, which would insert as `"account "`. Patch it
                # to trim that space. No-op when PSFzf didn't load; benefits Ctrl+T as well.
                Repair-PsFzfCompletionQuoting
                if ($psfzf.Count -gt 0 -and (Get-Command Set-PsFzfOption -ErrorAction SilentlyContinue)) {
                    Set-PsFzfOption @psfzf
                }
                # Fuzzy completion on its own chord, not Tab: Set-PsFzfOption -TabExpansion only targets
                # Tab, so bind Invoke-FzfTabCompletion directly and leave Tab = MenuComplete. The
                # scriptblock resolves the global Invoke-FzfTabCompletion at key-press time.
                if (-not [string]::IsNullOrWhiteSpace($TabExpansionChord) -and
                    (Get-Command Invoke-FzfTabCompletion -ErrorAction SilentlyContinue)) {
                    # Many terminals emit the same byte (NUL) for Ctrl+Spacebar and Ctrl+@, and PSReadLine
                    # may report either name — so bind both when the chord is one of that pair. Separate
                    # -Key array elements are independent bindings (a comma inside one string is a chord).
                    $tabKeys = if ($TabExpansionChord -in 'Ctrl+Spacebar', 'Ctrl+@') {
                        'Ctrl+Spacebar', 'Ctrl+@'
                    }
                    else { $TabExpansionChord }
                    Set-PSReadLineKeyHandler -Key $tabKeys -ScriptBlock { Invoke-FzfTabCompletion } `
                        -BriefDescription 'FzfTabCompletion' `
                        -Description 'Fuzzy completion picker via fzf (PSFzf)'
                }
            }
        }
    }
}
