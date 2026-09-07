function Get-FzfTabExpansionKey {
    <#
    .SYNOPSIS
        Expands a -TabExpansionChord value to the PSReadLine key(s) it actually binds to.

    .DESCRIPTION
        Shared between Enable-Fzf (which binds these keys) and Show-PwshProfileChord (which displays
        them): many terminals emit the same byte for Ctrl+Spacebar and Ctrl+@, so PSReadLine may
        report either name and that pair dual-binds; any other chord binds as itself.

    .PARAMETER Chord
        The requested tab-expansion chord. An empty value passes through unchanged — the caller
        decides what an unbound chord means.

    .EXAMPLE
        Get-FzfTabExpansionKey -Chord 'Ctrl+Spacebar'

        Returns 'Ctrl+Spacebar', 'Ctrl+@'.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Chord
    )

    if ($Chord -in 'Ctrl+Spacebar', 'Ctrl+@') { 'Ctrl+Spacebar', 'Ctrl+@' }
    else { $Chord }
}
