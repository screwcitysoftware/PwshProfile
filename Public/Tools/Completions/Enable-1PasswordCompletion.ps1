function Enable-1PasswordCompletion {
    <#
    .SYNOPSIS
        Registers tab completion for the 1Password CLI (op) in the current session.

    .DESCRIPTION
        The 1Password CLI (`op`) is a Cobra-based CLI, so this enabler delegates to the shared
        Register-CobraCompletion helper, which generates `op completion powershell` and activates it
        in the global scope. Register-CobraCompletion is guarded by Get-Command, so a missing `op` is
        a silent no-op.

        Like the other completion enablers, it only registers completion (no install phase) and opens
        no Invoke-Step of its own — the caller supplies the step label.

    .EXAMPLE
        Enable-1PasswordCompletion

        Registers 1Password CLI tab completion if op is installed.

    .EXAMPLE
        Invoke-Step "1Password Completions" { Enable-1PasswordCompletion }

        Registers it as a rendered startup substep.
    #>
    [CmdletBinding()]
    param()

    Register-CobraCompletion op
}
