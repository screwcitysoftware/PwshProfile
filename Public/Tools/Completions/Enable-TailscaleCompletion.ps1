function Enable-TailscaleCompletion {
    <#
    .SYNOPSIS
        Registers tab completion for the Tailscale CLI (tailscale) in the current session.

    .DESCRIPTION
        Tailscale ships a Cobra-based CLI, so this enabler delegates to the shared
        Register-CobraCompletion helper, which generates `tailscale completion powershell` and
        activates it in the global scope. Register-CobraCompletion is guarded by Get-Command, so a
        missing `tailscale` is a silent no-op.

        Like the other completion enablers, it only registers completion (no install phase) and opens
        no Invoke-Step of its own — the caller supplies the step label.

    .EXAMPLE
        Enable-TailscaleCompletion

        Registers Tailscale tab completion if tailscale is installed.

    .EXAMPLE
        Invoke-Step "Tailscale Completions" { Enable-TailscaleCompletion }

        Registers it as a rendered startup substep.
    #>
    [CmdletBinding()]
    param()

    Register-CobraCompletion tailscale
}
