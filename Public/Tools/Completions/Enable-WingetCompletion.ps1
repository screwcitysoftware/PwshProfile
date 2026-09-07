function Enable-WingetCompletion {
    <#
    .SYNOPSIS
        Registers native tab completion for the winget CLI in the current session.

    .DESCRIPTION
        Registers a native argument completer for `winget` that delegates to winget's own
        `winget complete` subcommand, so tab completion stays in sync with the installed winget
        version. It escapes embedded quotes before forwarding the word, command line, and cursor
        position. winget emits UTF-8, which the `.psm1` already sets at import, so the completer
        does not re-set the encoding the way Microsoft's stock snippet does.

        winget is assumed present (it is how this module installs every other tool), so there is
        no install step — the function only registers the completer. It opens no Invoke-Step of
        its own; wrap the call in one (the caller supplies the step label) if you want it rendered
        as a startup substep.

    .EXAMPLE
        Enable-WingetCompletion

        Registers winget tab completion directly.

    .EXAMPLE
        Invoke-Step "Winget Completions" { Enable-WingetCompletion }

        Registers it as a rendered startup substep.
    #>
    [CmdletBinding()]
    param()

    Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        # No encoding reset here — the .psm1 sets UTF-8 at import.
        $word = $wordToComplete.Replace('"', '""')
        $ast = $commandAst.ToString().Replace('"', '""')
        winget complete --word="$word" --commandline "$ast" --position $cursorPosition | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}
