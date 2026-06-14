function Get-PwshProfileMarker {
    <#
    .SYNOPSIS
        Returns the comment markers that delimit the managed bootstrap block in a profile file.

    .DESCRIPTION
        The single source of truth for the conda-style sentinel comments that wrap the
        ScrewCitySoftware.PwshProfile bootstrap. Install-PwshProfile (via
        Write-PwshProfileBlock) writes them, and Uninstall-PwshProfile locates and
        removes the region between them, so both sides must agree on the exact strings — hence one
        helper rather than copies scattered across functions.

        Returns a hashtable with two keys:
          Open  — the opening marker line.
          Close — the closing marker line.

    .EXAMPLE
        (Get-PwshProfileMarker).Open

        Returns '# >>> ScrewCitySoftware.PwshProfile bootstrap >>>'.
    #>
    [CmdletBinding()]
    param()

    @{
        Open  = '# >>> ScrewCitySoftware.PwshProfile bootstrap >>>'
        Close = '# <<< ScrewCitySoftware.PwshProfile bootstrap <<<'
    }
}
