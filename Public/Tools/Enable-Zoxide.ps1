function Enable-Zoxide {
    <#
    .SYNOPSIS
        Installs (if necessary) and activates zoxide directory jumping for the session.

    .DESCRIPTION
        Runs two nested Invoke-Step substeps:
          - Install: if zoxide.exe isn't on PATH, installs it with winget
            (ajeetdsouza.zoxide, a portable package) and patches the current session's PATH
            so the Initialize substep can see it immediately.
          - Initialize: runs `zoxide init powershell` and invokes the emitted script, which
            defines the global __zoxide_* helpers and the jump alias.

        If the install doesn't produce zoxide.exe on PATH, a warning is emitted (with winget's
        captured output) and Initialize is skipped (guarded by Get-Command) so profile startup
        continues.

    .PARAMETER Command
        The command name zoxide binds for jumping, passed as `--cmd`. Defaults to 'cd',
        which replaces the built-in cd (and adds cdi for interactive selection).

    .EXAMPLE
        Enable-Zoxide

    .EXAMPLE
        Enable-Zoxide -Command z
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Command = 'cd'
    )

    Invoke-Step "Install" {
        # zoxide is a winget portable: its exe lands in the default Links dir.
        Install-WingetPackageSafe -Id 'ajeetdsouza.zoxide' -Exe 'zoxide.exe' -CallerName 'Enable-Zoxide'
    }

    Invoke-Step "Initialize" {
        if (Get-Command zoxide.exe -ErrorAction SilentlyContinue) {
            # Run in the global scope (not this module's) so the emitted __zoxide_* helpers
            # aren't tagged to the module — see Private/Invoke-InGlobalScope.ps1.
            Invoke-InGlobalScope (zoxide init powershell --cmd $Command | Out-String)
        }
    }
}
