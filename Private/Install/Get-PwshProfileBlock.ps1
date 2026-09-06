function Get-PwshProfileBlock {
    <#
    .SYNOPSIS
        Builds the full marker-wrapped bootstrap block written into a profile file.

    .DESCRIPTION
        The single source of truth for the managed block's text. Both the real write
        (Write-PwshProfileBlock) and the wizard's preview panel (Install-PwshProfile) build
        the block through this helper so the preview always matches what lands on disk.

        The block is the open marker, a short guidance comment for anyone editing the profile by
        hand, the supplied Initialize-PwshProfile call, and the close marker — joined by the platform
        newline. Markers come from Get-PwshProfileMarker.

        There is no Import-Module line: invoking Initialize-PwshProfile auto-loads the module (its
        manifest lists an explicit FunctionsToExport, so command discovery finds it), keeping the
        block to a guidance comment, the snapshot, and the one call.

    .PARAMETER InitializeCall
        The Initialize-PwshProfile command line to embed (as produced by
        Build-PwshProfileInitializeCall).

    .EXAMPLE
        Get-PwshProfileBlock -InitializeCall 'Initialize-PwshProfile -Theme forestcity'

        Returns the full block (markers, guidance comment, and the Initialize call).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$InitializeCall
    )

    $marker = Get-PwshProfileMarker

    ($marker.Open,
        '# Managed by Install-PwshProfile. To change these settings, RE-RUN Install-PwshProfile rather',
        '# than editing by hand: the installer reads the call below to prefill your prior choices.',
        '# Manual edits between the >>> / <<< markers are overwritten on the next Install; put your own',
        '# code outside them. Uninstall-PwshProfile removes it.',
        $InitializeCall,
        $marker.Close) -join [Environment]::NewLine
}
