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
                .gitignore). The Ctrl+T file picker is driven by PSFzf's own fd provider
                (Set-PsFzfOption -EnableFd, set by Enable-Fzf), so no FZF_CTRL_T_COMMAND is needed.
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
        When set (and fzf.exe is on PATH), wires fzf to use fd as its file source by setting
        $env:FZF_DEFAULT_COMMAND (the command a bare `fzf` runs). Off by default. Initialize-PwshProfile
        passes this when fzf is not skipped; the inner Get-Command fzf.exe guard means it is a no-op
        when fzf isn't installed.

    .EXAMPLE
        Enable-Fd

        Installs fd if needed and registers its tab completion, leaving colors and fzf alone.

    .EXAMPLE
        Enable-Fd -LsColors 'di=1;38;2;201;170;255:ln=38;2;95;215;255' -IntegrateFzf

        Colors fd's output to match the Screw City palette and points fzf at fd as its source.

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
            # fd colors come from $env:LS_COLORS (process-global already, so a plain assignment —
            # no Invoke-InGlobalScope needed for env vars).
            if (-not [string]::IsNullOrWhiteSpace($LsColors)) { $env:LS_COLORS = $LsColors }

            # Register fd's completer in the global scope (not this module's) so it isn't tagged to
            # the module — see Private/Core/Invoke-InGlobalScope.ps1.
            Invoke-InGlobalScope ((fd --gen-completions powershell) | Out-String)

            # When asked, point fzf at fd as its source (only if fzf is actually present). A bare
            # `fzf` reads $env:FZF_DEFAULT_COMMAND directly; fzf's own palette/--ansi is set by
            # Enable-Fzf. The Ctrl+T widget is driven by PSFzf's own fd provider (Set-PsFzfOption
            # -EnableFd), so there's no FZF_CTRL_T_COMMAND to set here.
            if ($IntegrateFzf -and (Get-Command fzf.exe -ErrorAction SilentlyContinue)) {
                $env:FZF_DEFAULT_COMMAND = 'fd --type file --color=always --hidden --follow --exclude .git'
            }
        }
    }
}
