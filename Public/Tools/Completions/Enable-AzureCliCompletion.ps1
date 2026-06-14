function Enable-AzureCliCompletion {
    <#
    .SYNOPSIS
        Registers native tab completion for the Azure CLI (az) in the current session.

    .DESCRIPTION
        Registers a native argument completer for `az` that drives the CLI's Python argcomplete
        engine: it sets the `_ARGCOMPLETE` / `COMP_*` environment variables, points argcomplete at a
        temporary file (`ARGCOMPLETE_USE_TEMPFILES`), runs `az` once to emit the candidate
        completions into that file, then reads, sorts, and returns them as completion results before
        cleaning up the temp file and the environment variables it set.

        Unlike a Cobra CLI, `az` has no `completion powershell` subcommand, so this can't go through
        Register-CobraCompletion — the argcomplete protocol above is the supported mechanism (see the
        Azure CLI docs). The completer defines no helper functions, so it needs no Invoke-InGlobalScope.

        Guarded by Get-Command: if `az` isn't on PATH, the function does nothing — keeping profile
        startup tolerant of a missing Azure CLI. It opens no Invoke-Step of its own; wrap the call in
        one (the caller supplies the step label) to render it as a startup substep.

    .EXAMPLE
        Enable-AzureCliCompletion

        Registers Azure CLI tab completion if az is installed.

    .EXAMPLE
        Invoke-Step "Azure CLI Completions" { Enable-AzureCliCompletion }

        Registers it as a rendered startup substep.

    .NOTES
        Mirrors the official enabler from
        https://learn.microsoft.com/cli/azure/use-azure-cli-successfully-powershell#enable-tab-completion-in-powershell.
        To display completions as a navigable menu, bind Tab to MenuComplete — Initialize-PSReadline
        does this for the profile.
    #>
    [CmdletBinding()]
    param()

    if (-not (Get-Command az -ErrorAction SilentlyContinue)) { return }

    Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
        param($commandName, $wordToComplete, $cursorPosition)
        $completion_file = New-TemporaryFile
        # try/finally so a throw from `az` or Get-Content can't leak the temp file or the env vars
        # this completer sets into the session; cleanup runs unconditionally in finally.
        try {
            $env:ARGCOMPLETE_USE_TEMPFILES = 1
            $env:_ARGCOMPLETE_STDOUT_FILENAME = $completion_file
            $env:COMP_LINE = $wordToComplete
            $env:COMP_POINT = $cursorPosition
            $env:_ARGCOMPLETE = 1
            $env:_ARGCOMPLETE_SUPPRESS_SPACE = 0
            $env:_ARGCOMPLETE_IFS = "`n"
            $env:_ARGCOMPLETE_SHELL = 'powershell'
            az 2>&1 | Out-Null
            Get-Content $completion_file | Sort-Object | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_, $_, "ParameterValue", $_)
            }
        }
        finally {
            Remove-Item $completion_file, Env:\_ARGCOMPLETE_STDOUT_FILENAME, Env:\ARGCOMPLETE_USE_TEMPFILES, Env:\COMP_LINE, Env:\COMP_POINT, Env:\_ARGCOMPLETE, Env:\_ARGCOMPLETE_SUPPRESS_SPACE, Env:\_ARGCOMPLETE_IFS, Env:\_ARGCOMPLETE_SHELL -ErrorAction SilentlyContinue
        }
    }
}
