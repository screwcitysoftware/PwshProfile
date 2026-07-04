function Enable-Lazygit {
    <#
    .SYNOPSIS
        Installs (if necessary) lazygit, the terminal UI for git, for the session.

    .DESCRIPTION
        Runs two nested Invoke-Step substeps:
          - Install: if lazygit.exe isn't on PATH, installs it with winget (JesseDuffield.lazygit, a
            portable package) and patches the current session's PATH so the exe is usable
            immediately.
          - Initialize: a Get-Command-guarded no-op. lazygit is a self-contained full-screen TUI you
            launch by typing `lazygit` — it ships no PowerShell shell-init or tab-completion script
            (unlike the Cobra CLIs that emit `<cmd> completion powershell`), so there's nothing to
            run. The substep exists only to keep the install/initialize shape consistent with the
            other tool enablers and to gate on the exe being present.

        If the install doesn't produce lazygit.exe on PATH, a warning is emitted (with winget's
        captured output) so profile startup continues either way.

    .EXAMPLE
        Enable-Lazygit

    .NOTES
        Terminal UI for git (https://github.com/jesseduffield/lazygit). lazygit has no built-in shell
        completion, so this is install-only — there is no Enable-LazygitCompletion and no completion
        is registered.
    #>
    [CmdletBinding()]
    param()

    Invoke-Step "Install" {
        # lazygit is a winget portable: its exe lands in the default Links dir.
        Install-WingetPackageSafe -Id 'JesseDuffield.lazygit' -Exe 'lazygit.exe' -CallerName 'Enable-Lazygit'
    }

    Invoke-Step "Initialize" {
        if (Get-Command lazygit.exe -ErrorAction SilentlyContinue) {
            # No-op: lazygit has no PowerShell init/completion script to run. Just having lazygit.exe
            # on PATH is enough to launch the TUI directly.
        }
    }
}
