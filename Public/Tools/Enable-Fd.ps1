function Enable-Fd {
    <#
    .SYNOPSIS
        Installs (if necessary) and activates fd, a fast and friendly `find` alternative, for the
        session.

    .DESCRIPTION
        Runs two nested Invoke-Step substeps:
          - Install: if fd.exe isn't on PATH, installs it with winget (sharkdp.fd, a portable
            package) and patches the current session's PATH so the Initialize substep can see it
            immediately.
          - Initialize (guarded by Get-Command fd.exe): configures fd for the session:
              * When -LsColors is non-empty, sets $env:LS_COLORS so fd's output (directories,
                symlinks, executables, …) is colored to match the active oh-my-posh theme.
                Initialize-PwshProfile resolves this from the theme's branding. fd has no
                fd-specific color variable — LS_COLORS is the mechanism it (and ls/eza) read — so an
                empty value leaves LS_COLORS untouched.
              * Registers fd's PowerShell tab completion. fd emits a Register-ArgumentCompleter
                script via `fd --gen-completions powershell`; it is run through Invoke-InGlobalScope
                (not a bare Invoke-Expression) so the registered completer lands in the true global
                scope and isn't tagged to this module — see Private/Core/Invoke-InGlobalScope.ps1.
              * When -IntegrateFzf is set and fzf.exe is on PATH, points fzf at fd as its source by
                setting $env:FZF_DEFAULT_COMMAND, so a bare `fzf` lists files via fd (respecting
                .gitignore). PSFzf's Ctrl+T file picker reads that same variable in preference to its
                own fd command, so no FZF_CTRL_T_COMMAND is needed either.
              * PSFzf's Alt+C directory picker, however, does NOT read FZF_DEFAULT_COMMAND: its
                directory-only lookup skips it and falls back to a built-in PSFzf command
                (`fd --full-path <dir> --fixed-strings .`) whose literal `.` pattern matches only
                paths containing a period — so on Windows that picker comes up empty. PSFzf checks
                $env:FZF_ALT_C_COMMAND ahead of that fallback, so it is set here too, to a plain
                `fd --type directory` listing.
                Both commands pass --ignore-case so any fd-side matching stays case-insensitive
                (PowerShell/Windows is); note fd is used in list-all mode here, so the picker's case
                behavior is ultimately governed by fzf (see Enable-Fzf).
                fzf's own picker palette is themed separately by Enable-Fzf (which owns
                $env:FZF_DEFAULT_OPTS, including the --ansi that renders fd's `--color=always`
                output in the picker).

        fd is a STANDALONE utility: it never aliases or replaces Get-ChildItem, `ls`, or any other
        configured command. Enabling it only puts `fd` on PATH (plus colors and completion).

        If the install doesn't produce fd.exe on PATH, a warning is emitted (with winget's captured
        output) and Initialize is skipped (guarded by Get-Command) so profile startup continues.

    .PARAMETER LsColors
        An LS_COLORS spec assigned to $env:LS_COLORS for the session (e.g.
        'di=1;38;2;201;170;255:ln=38;2;95;215;255'), coloring fd's output. Initialize-PwshProfile
        resolves this from the active theme's branding so fd's colors match the prompt. An empty
        value leaves $env:LS_COLORS untouched. Note: LS_COLORS is a shared variable also read by ls
        and eza.

    .PARAMETER IntegrateFzf
        When set (and fzf.exe is on PATH), wires fzf to use fd as its source by setting two env vars:
        $env:FZF_DEFAULT_COMMAND (the file listing a bare `fzf` runs, which PSFzf's Ctrl+T picker also
        prefers over its own fd command) and $env:FZF_ALT_C_COMMAND (the directory listing PSFzf's
        Alt+C picker runs, which would otherwise fall back to a built-in PSFzf command that matches
        nothing). Off by default. Initialize-PwshProfile passes this when fzf is enabled; the inner
        Get-Command fzf.exe guard means it is a no-op when fzf isn't installed.

    .EXAMPLE
        Enable-Fd

        Installs fd if needed and registers its tab completion, leaving colors and fzf alone.

    .EXAMPLE
        Enable-Fd -LsColors 'di=1;38;2;201;170;255:ln=38;2;95;215;255' -IntegrateFzf

        Colors fd's output to match the Screw City palette and points fzf at fd as its source — both
        the file listing (bare `fzf` and PSFzf's Ctrl+T) and the directory listing (PSFzf's Alt+C).

    .NOTES
        Standalone file finder (https://github.com/sharkdp/fd). fd is clap-based, so it ships its own
        PowerShell completer (`fd --gen-completions powershell`), registered here in the Initialize
        substep (run in the global scope so it isn't attributed to the module). Call after Enable-Fzf
        so fzf.exe is already on PATH when -IntegrateFzf is evaluated.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$LsColors,

        [Parameter()]
        [switch]$IntegrateFzf
    )

    Invoke-Step "Install" {
        # fd is a winget portable: its exe lands in the default Links dir.
        Install-WingetPackageSafe -Id 'sharkdp.fd' -Exe 'fd.exe' -CallerName 'Enable-Fd'
    }

    Invoke-Step "Initialize" {
        if (Get-Command fd.exe -ErrorAction SilentlyContinue) {
            # Env vars are process-global, so a plain assignment — no Invoke-InGlobalScope needed.
            if (-not [string]::IsNullOrWhiteSpace($LsColors)) { $env:LS_COLORS = $LsColors }

            # Global scope so fd's completer isn't tagged to this module.
            Invoke-InGlobalScope ((fd --gen-completions powershell) | Out-String)

            # Point fzf at fd as its source when fzf is present. A bare `fzf` reads FZF_DEFAULT_COMMAND
            # directly and PSFzf's Ctrl+T widget prefers it, so there is no FZF_CTRL_T_COMMAND to set.
            if ($IntegrateFzf -and (Get-Command fzf.exe -ErrorAction SilentlyContinue)) {
                $env:FZF_DEFAULT_COMMAND = 'fd --ignore-case --type file --color=always --hidden --follow --exclude .git'
                # Alt+C (PSFzf's set-location picker) is the one path that ignores FZF_DEFAULT_COMMAND:
                # its directory branch falls back to PSFzf's `fd ... --fixed-strings .`, whose literal
                # `.` matches only paths containing a period, so the picker comes up empty on Windows.
                # FZF_ALT_C_COMMAND takes precedence — give it a straight directory listing.
                $env:FZF_ALT_C_COMMAND = 'fd --ignore-case --type directory --color=always --hidden --follow --exclude .git'
            }
        }
    }
}
