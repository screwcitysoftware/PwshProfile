function Get-BundledFontName {
    <#
    .SYNOPSIS
        Returns the names of the FIGlet fonts bundled with the module.

    .DESCRIPTION
        The single source of truth for which fonts are available: enumerates Assets/Fonts/*.flf
        (resolved via Get-BundledFontPath) and returns their sorted base names. These are the
        values accepted by Write-Figlet -Font, Show-FigletFont -Font, and
        Initialize-PwshProfile -BannerFont.

        Drives the dynamic -Font validation and tab-completion on those functions, so adding or
        removing a .flf in Assets/Fonts changes the accepted set with no code edits. Returns
        nothing if the folder is missing (callers degrade rather than throw).

    .EXAMPLE
        Get-BundledFontName

        Returns e.g. 3D-ASCII, ANSIRegular, ANSIShadow, ... (one per bundled .flf).
    #>
    [CmdletBinding()]
    param()

    Get-ChildItem -Path (Get-BundledFontPath) -Filter *.flf -ErrorAction SilentlyContinue |
        Sort-Object BaseName |
        Select-Object -ExpandProperty BaseName
}
