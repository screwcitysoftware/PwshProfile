function Initialize-PSReadline {
    <#
    .SYNOPSIS
        Configures PSReadLine options and custom key handlers for the session.

    .DESCRIPTION
        Applies the PSReadLine options (history behavior, prediction source/view, edit mode,
        bell style) and registers the key handlers used in this profile:
          - UpArrow / DownArrow do history search.
          - Tab triggers menu completion (a navigable list of completions).
          - Alt+w saves the current line to history without executing it.
          - Alt+( wraps the selection (or the whole line) in parentheses.

        Safe to call more than once; re-running simply re-applies the same options and bindings.

    .EXAMPLE
        Initialize-PSReadline

    .NOTES
        Based on the PSReadLine sample profile:
        https://github.com/PowerShell/PSReadLine/blob/master/PSReadLine/SamplePSReadLineProfile.ps1

        No-ops if PSReadLine is unavailable (guarded on Set-PSReadLineOption), so a minimal or
        constrained host without the module never throws out of profile startup.
    #>
    [CmdletBinding()]
    param()

    # PSReadLine ships with pwsh, but a minimal/constrained host may lack it. Guard so startup stays
    # tolerant — all the cmdlets below live in the same module, so one resolved check covers them all.
    if (-not (Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue)) { return }

    ### PS ReadLine ###

    Set-PSReadLineOption -HistoryNoDuplicates
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineOption -MaximumHistoryCount 5000
    Set-PSReadLineOption -BellStyle Visual
    # Predictions require a real interactive console — PSReadLine errors out when output
    # is redirected (e.g. scripted `pwsh -Command` runs), so skip them in that case.
    if (-not [Console]::IsOutputRedirected) {
        Set-PSReadLineOption -PredictionSource History
        Set-PSReadLineOption -PredictionViewStyle ListView
    }
    Set-PSReadLineOption -EditMode Windows

    Set-PSReadLineKeyHandler -Chord 'UpArrow' -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Chord 'DownArrow' -Function HistorySearchForward

    # Show completions (e.g. the Azure CLI's) as a navigable menu rather than cycling inline.
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

    # Sometimes you enter a command but realize you forgot to do something else first.
    # This binding will let you save that command in the history so you can recall it,
    # but it doesn't actually execute.  It also clears the line with RevertLine so the
    # undo stack is reset - though redo will still reconstruct the command line.
    Set-PSReadLineKeyHandler -Key Alt+w `
        -BriefDescription SaveInHistory `
        -LongDescription "Save current line in history but do not execute" `
        -ScriptBlock {
        param($key, $arg)

        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        [Microsoft.PowerShell.PSConsoleReadLine]::AddToHistory($line)
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    }

    # Sometimes you want to get a property of invoke a member on what you've entered so far
    # but you need parens to do that.  This binding will help by putting parens around the current selection,
    # or if nothing is selected, the whole line.
    Set-PSReadLineKeyHandler -Key 'Alt+(' `
        -BriefDescription ParenthesizeSelection `
        -LongDescription "Put parenthesis around the selection or entire line and move the cursor to after the closing parenthesis" `
        -ScriptBlock {
        param($key, $arg)

        $selectionStart = $null
        $selectionLength = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)

        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        if ($selectionStart -ne -1) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, '(' + $line.SubString($selectionStart, $selectionLength) + ')')
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
        }
        else {
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, '(' + $line + ')')
            [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine()
        }
    }
}
