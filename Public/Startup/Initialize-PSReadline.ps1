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

    # PSReadLine ships with pwsh but a minimal host may lack it; one check covers the whole module.
    if (-not (Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue)) { return }

    ### PS ReadLine ###

    Set-PSReadLineOption -HistoryNoDuplicates
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineOption -MaximumHistoryCount 5000
    Set-PSReadLineOption -BellStyle Visual
    # PSReadLine errors on predictions when output is redirected (e.g. scripted pwsh -Command runs).
    if (-not [Console]::IsOutputRedirected) {
        Set-PSReadLineOption -PredictionSource History
        Set-PSReadLineOption -PredictionViewStyle ListView
    }
    Set-PSReadLineOption -EditMode Windows

    Set-PSReadLineKeyHandler -Chord 'UpArrow' -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Chord 'DownArrow' -Function HistorySearchForward

    # Show completions (e.g. the Azure CLI's) as a navigable menu rather than cycling inline.
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

    # Park a half-typed command in history without running it, then clear the line. RevertLine resets
    # the undo stack, though redo still reconstructs the command line.
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

    # Wrap the current selection — or the whole line when nothing is selected — in parens.
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
