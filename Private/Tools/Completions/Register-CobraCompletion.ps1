function Register-CobraCompletion {
    <#
    .SYNOPSIS
        Registers tab completion for a Cobra-based CLI (e.g. tailscale, op) in the current session.

    .DESCRIPTION
        Generates a tool's PowerShell completion script with `<Command> completion powershell` and
        activates it via Invoke-InGlobalScope, which runs it in the global scope so the script's
        helper functions/filters are reachable when the registered completer fires at tab time (and
        aren't tagged to this module).

        This is the shared, module-private engine for Cobra-based CLIs; the public per-tool enablers
        (Enable-TailscaleCompletion, Enable-1PasswordCompletion) wrap it. Guarded by Get-Command: if
        the tool isn't on PATH, the function does nothing — keeping profile startup tolerant of tools
        that aren't installed.

    .PARAMETER Command
        Name of the Cobra-based CLI whose completions to register (for example, `tailscale` or
        `op`). The function calls `<Command> completion powershell` and resolves the executable on
        PATH via Get-Command.

    .EXAMPLE
        Register-CobraCompletion tailscale

        Registers Tailscale tab completion if tailscale is installed. (Enable-TailscaleCompletion
        is the public wrapper that calls this.)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Command
    )

    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        Invoke-InGlobalScope (& $Command completion powershell | Out-String)
    }
}
