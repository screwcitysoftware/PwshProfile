function Enable-Jq {
    <#
    .SYNOPSIS
        Installs (if necessary) jq, the command-line JSON processor, for the session.

    .DESCRIPTION
        Runs two nested Invoke-Step substeps:
          - Install: if jq.exe isn't on PATH, installs it with winget (jqlang.jq, a
            portable package) and patches the current session's PATH so the exe is usable
            immediately.
          - Initialize: a Get-Command-guarded no-op. jq is a standalone C program with a
            hand-rolled argument parser — it ships no PowerShell shell-init or tab-completion
            script (unlike the Cobra CLIs that emit `<cmd> completion powershell`), so there's
            nothing to run. The substep exists only to keep the install/initialize shape
            consistent with the other tool enablers and to gate on the exe being present.

        If the install doesn't produce jq.exe on PATH, a warning is emitted (with winget's
        captured output) so profile startup continues either way.

    .EXAMPLE
        Enable-Jq

    .NOTES
        Standalone JSON processor (https://jqlang.github.io/jq/). jq has no built-in shell
        completion, so this is install-only — there is no Enable-JqCompletion and no completion
        is registered.
    #>
    [CmdletBinding()]
    param()

    Invoke-Step "Install" {
        # jq is a winget portable: its exe lands in the default Links dir.
        Install-WingetPackageSafe -Id 'jqlang.jq' -Exe 'jq.exe' -CallerName 'Enable-Jq'
    }

    Invoke-Step "Initialize" {
        if (Get-Command jq.exe -ErrorAction SilentlyContinue) {
            # No-op: jq has no PowerShell init/completion script to run. Just having jq.exe on
            # PATH is enough for direct CLI use.
        }
    }
}
