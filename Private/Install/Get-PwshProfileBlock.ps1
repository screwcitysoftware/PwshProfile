function Get-PwshProfileBlock {
    <#
    .SYNOPSIS
        Builds the full marker-wrapped bootstrap block written into a profile file.

    .DESCRIPTION
        The single source of truth for the managed block's text. Both the real write
        (Write-PwshProfileBlock) and the wizard's preview panel (Install-PwshProfile) build
        the block through this helper so the preview always matches what lands on disk.

        The block is the open marker, a short guidance comment for anyone editing the profile by
        hand, the module import, a blank line, the supplied Initialize-PwshProfile call, and the
        close marker — joined by the platform newline. Markers come from Get-PwshProfileMarker.

    .PARAMETER InitializeCall
        The Initialize-PwshProfile command line to embed (as produced by
        Build-PwshProfileInitializeCall).

    .EXAMPLE
        Get-PwshProfileBlock -InitializeCall 'Initialize-PwshProfile'

        Returns the full block (markers, guidance comment, import, and the bare Initialize call).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$InitializeCall
    )

    $marker = Get-PwshProfileMarker

    ($marker.Open,
        '# Managed by Install-PwshProfile. Re-run it to change these settings, or run',
        '# Uninstall-PwshProfile to remove this block (or just delete these marker lines',
        '# yourself). Manual edits between the >>> / <<< markers are overwritten on the next',
        '# Install — put your own code outside them.',
        'Import-Module ScrewCitySoftware.PwshProfile',
        '',
        $InitializeCall,
        $marker.Close) -join [Environment]::NewLine
}
