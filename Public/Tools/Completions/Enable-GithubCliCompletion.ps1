function Enable-GithubCliCompletion {
    <#
    .SYNOPSIS
        Registers tab completion for the GitHub CLI (gh) in the current session.

    .DESCRIPTION
        The GitHub CLI (`gh`) is a Cobra-based CLI, so this enabler delegates to the shared
        Register-CobraCompletion helper, which generates `gh completion -s powershell` and activates
        it in the global scope. Unlike most Cobra CLIs, `gh` requires the shell as a flag (`-s
        powershell`) — a bare positional `gh completion powershell` makes gh emit bash instead — so
        this enabler overrides the helper's default generation args. Register-CobraCompletion is
        guarded by Get-Command, so a missing `gh` is a silent no-op.

        Like the other completion enablers, it only registers completion (no install phase) and opens
        no Invoke-Step of its own — the caller supplies the step label.

    .EXAMPLE
        Enable-GithubCliCompletion

        Registers GitHub CLI tab completion if gh is installed.

    .EXAMPLE
        Invoke-Step "GitHub CLI Completions" { Enable-GithubCliCompletion }

        Registers it as a rendered startup substep.
    #>
    [CmdletBinding()]
    param()

    Register-CobraCompletion gh -CompletionArgument 'completion', '-s', 'powershell'
}
