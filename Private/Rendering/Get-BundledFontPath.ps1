function Get-BundledFontPath {
    <#
    .SYNOPSIS
        Returns the absolute path to a bundled FIGlet font (or the bundled fonts folder).

    .DESCRIPTION
        Single source of truth for the location of the module's bundled FIGlet fonts
        (Assets/Fonts/*.flf), the companion to Get-BundledThemePath. Reused by Write-Figlet (to
        resolve a -Font name to its .flf) and Show-FigletFont (to enumerate the folder), so
        the path is resolved one way. $PSScriptRoot here is Private/Rendering/, so '..\..' reaches
        the module root and 'Assets/Fonts' the font folder beneath it.

        With a -Name, returns the path to that font's file (Assets/Fonts/<Name>.flf); without one,
        returns the Assets/Fonts directory itself. The path is returned whether or not it exists;
        callers decide how to handle a missing file (Write-Figlet warns and falls back to the
        default font).

    .PARAMETER Name
        The bundled font's base name (e.g. 'ANSIShadow'), matching the file name without its .flf
        extension. When omitted, the fonts directory path is returned instead.

    .EXAMPLE
        $font = Get-BundledFontPath -Name 'ANSIShadow'

        Resolves the path to Assets/Fonts/ANSIShadow.flf.

    .EXAMPLE
        Get-ChildItem (Get-BundledFontPath) -Filter *.flf

        Enumerates every bundled font file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Name
    )

    $fontsDir = Join-Path $PSScriptRoot '..' '..' 'Assets' 'Fonts'
    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $fontsDir
    }

    Join-Path $fontsDir "$Name.flf"
}
