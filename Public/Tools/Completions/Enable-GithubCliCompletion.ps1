function Enable-GithubCliCompletion {
    <#
    .SYNOPSIS
        Registers tab completion for the GitHub CLI (gh) in the current session.

    .DESCRIPTION
        The GitHub CLI (`gh`) is a Cobra-based CLI, so this enabler delegates to the shared
        Register-CobraCompletion helper, which generates `gh completion powershell` and activates it
        in the global scope. Register-CobraCompletion is guarded by Get-Command, so a missing `gh` is
        a silent no-op.

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

    Register-CobraCompletion gh
}
