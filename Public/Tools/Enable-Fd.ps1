function Enable-Fd {
    <#
    .SYNOPSIS
        Installs (if necessary) and activates fd, a fast and friendly `find` alternative.

    .DESCRIPTION
        Runs two nested Invoke-Step substeps:
          - Install: if fd.exe isn't on PATH, installs sharkdp.fd with winget and patches the current
            session's PATH so the Initialize substep can see it immediately.
          - Initialize (guarded by Get-Command fd.exe): sets $env:LS_COLORS from -LsColors (fd has no
            color variable of its own), registers fd's own PowerShell completer via
            `fd --gen-completions powershell` through Invoke-InGlobalScope, and optionally wires fzf.

        -IntegrateFzf sets two variables because PSFzf reads them differently. $env:FZF_DEFAULT_COMMAND
        covers a bare `fzf` and PSFzf's Ctrl+T picker, which prefers it over its own fd command. Alt+C
        does not read it at all: PSFzf's directory lookup falls back to a built-in
        `fd --full-path <dir> --fixed-strings .`, whose literal `.` matches only paths containing a
        period, so on Windows that picker comes up empty. $env:FZF_ALT_C_COMMAND takes precedence over
        that fallback, so it is set to a plain directory listing. Both pass --ignore-case, though fd
        runs in list-all mode here so fzf ultimately does the matching.

        fd is a standalone utility: it never aliases or replaces Get-ChildItem, `ls`, or anything else.
        Enabling it only puts `fd` on PATH, with colors and completion. If the install doesn't produce
        fd.exe on PATH, a warning is emitted and Initialize is skipped so startup continues.

    .PARAMETER LsColors
        An LS_COLORS spec assigned to $env:LS_COLORS for the session, coloring fd's output.
        Initialize-PwshProfile resolves this from the active theme's branding. Empty leaves the
        variable untouched. Note LS_COLORS is shared with ls and eza.

    .PARAMETER IntegrateFzf
        Point fzf at fd as its source, setting $env:FZF_DEFAULT_COMMAND and $env:FZF_ALT_C_COMMAND as
        described above. Off by default. Guarded by Get-Command fzf.exe, so it no-ops without fzf.

    .EXAMPLE
        Enable-Fd

        Installs fd if needed and registers its tab completion, leaving colors and fzf alone.

    .EXAMPLE
        Enable-Fd -LsColors 'di=1;38;2;201;170;255:ln=38;2;95;215;255' -IntegrateFzf

        Colors fd's output to match the Screw City palette and points fzf at fd for both its file and
        directory listings.

    .NOTES
        Standalone file finder (https://github.com/sharkdp/fd). fzf's own picker palette is themed
        separately by Enable-Fzf, which owns $env:FZF_DEFAULT_OPTS. Call after Enable-Fzf so fzf.exe is
        already on PATH when -IntegrateFzf is evaluated.
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
