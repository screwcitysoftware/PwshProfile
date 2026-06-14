function Register-CobraCompletion {
    <#
    .SYNOPSIS
        Registers tab completion for a Cobra-based CLI (e.g. tailscale, op) in the current session.

    .DESCRIPTION
        Generates a tool's PowerShell completion script (by default with `<Command> completion
        powershell`) and activates it via Invoke-InGlobalScope, which runs it in the global scope so
        the script's helper functions/filters are reachable when the registered completer fires at
        tab time (and aren't tagged to this module).

        This is the shared, module-private engine for Cobra-based CLIs; the public per-tool enablers
        (Enable-TailscaleCompletion, Enable-1PasswordCompletion, Enable-GithubCliCompletion) wrap it.
        Most Cobra CLIs take the shell positionally (`completion powershell`), but some — notably
        `gh` — require a flag (`completion -s powershell`); a bare positional `powershell` makes gh
        emit bash instead. The -CompletionArgument parameter exists to override the generation args
        for those CLIs. Guarded by Get-Command: if the tool isn't on PATH, the function does nothing
        — keeping profile startup tolerant of tools that aren't installed.

    .PARAMETER Command
        Name of the Cobra-based CLI whose completions to register (for example, `tailscale` or
        `op`). The function resolves the executable on PATH via Get-Command.

    .PARAMETER CompletionArgument
        The arguments passed to the CLI to emit its PowerShell completion script. Defaults to
        `completion`, `powershell` (the positional form most Cobra CLIs use). Override for CLIs that
        require a flag — e.g. `gh` needs `completion`, `-s`, `powershell`.

    .EXAMPLE
        Register-CobraCompletion tailscale

        Registers Tailscale tab completion if tailscale is installed. (Enable-TailscaleCompletion
        is the public wrapper that calls this.)

    .EXAMPLE
        Register-CobraCompletion gh -CompletionArgument 'completion', '-s', 'powershell'

        Registers GitHub CLI tab completion using gh's flag-style shell selection.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Command,

        [Parameter()]
        [string[]]$CompletionArgument = @('completion', 'powershell')
    )

    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        Invoke-InGlobalScope (& $Command @CompletionArgument | Out-String)
    }
}
