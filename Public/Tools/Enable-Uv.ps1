function Enable-Uv {
    <#
    .SYNOPSIS
        Installs (if necessary) and activates uv, the fast Python package and project manager.

    .DESCRIPTION
        Runs two nested Invoke-Step substeps:
          - Install: if uv.exe isn't on PATH, installs astral-sh.uv with winget and patches the
            current session's PATH so the Initialize substep can see it immediately.
          - Initialize (guarded by Test-CommandAvailable): registers uvx's own PowerShell completer
            through Invoke-InGlobalScope. `uv`'s completer is deliberately NOT registered — see .NOTES.

        uv is a single Rust binary that covers what pip, pip-tools, pipx, venv, and pyenv do
        separately: resolving and installing dependencies, managing per-project virtual environments,
        installing Python interpreters, and running tools in throwaway environments (`uvx`).

        The package ships three executables — uv.exe, uvx.exe, and uvw.exe (a console-less variant
        for GUI launches). PowerShell completers are registered per command name and don't follow a
        sibling exe, so each would need its own registration; uvw is left uncompleted since it isn't
        something you type at a prompt.

        uv is standalone: enabling it only puts the binaries on PATH. It never aliases or replaces
        `python`, `pip`, or `py`. If the install doesn't produce uv.exe on PATH, a warning is emitted
        and Initialize is skipped so startup continues.

    .EXAMPLE
        Enable-Uv

        Installs uv if needed and registers tab completion for `uvx`.

    .NOTES
        Standalone Python toolchain (https://docs.astral.sh/uv/).

        ONLY uvx's completer is registered, and that is a deliberate cost decision rather than an
        oversight. uv's own completer is ~754 KB of generated PowerShell — its CLI surface is huge —
        and startup pays to both produce and parse it: measured at 141 ms to generate plus 103 ms
        through Invoke-InGlobalScope, ~244 ms in total, against ~49 ms for uvx and ~42 ms for
        ripgrep. That made it the single most expensive step in the whole profile, roughly a quarter
        of the entire WinGet section, for one tool's tab completion. The trade-off is understood and
        accepted: `uv` is the command typed more often, so this keeps the cheaper half rather than
        the more useful one. Re-registering it is a one-line change if the cost ever becomes worth
        paying; Tests/Enable-Uv.Tests.ps1 pins the current choice so it can't drift back silently.

        Mind the asymmetry if you do: uv spells the request as a subcommand (`uv
        generate-shell-completion powershell`) while uvx — which has no subcommands of its own, since
        its first argument is the tool to run — spells it as a flag (`uvx
        --generate-shell-completion powershell`).

        uv is not themed here: it has no color environment variable, and its defaults live in
        pyproject.toml / uv.toml files you own rather than in the environment. It has no init-time
        dependency on the other tools, so its position in the startup order is free.
    #>
    [CmdletBinding()]
    param()

    Invoke-Step "Install" {
        # uv is a winget portable: its exes land in the default Links dir.
        Install-WingetPackageSafe -Id 'astral-sh.uv' -Exe 'uv.exe' -CallerName 'Enable-Uv'
    }

    Invoke-Step "Initialize" {
        if (Test-CommandAvailable -Name 'uv.exe') {
            # Global scope so the completer isn't tagged to this module. uvx only: `uv`'s own
            # completer costs ~244ms of every startup (754 KB of generated PowerShell) and is
            # deliberately skipped -- see .NOTES before adding it back.
            Invoke-InGlobalScope ((uvx --generate-shell-completion powershell) | Out-String)
        }
    }
}
