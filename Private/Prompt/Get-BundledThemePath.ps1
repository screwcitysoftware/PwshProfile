function Get-BundledThemePath {
    <#
    .SYNOPSIS
        Returns the absolute path to one of the module's bundled oh-my-posh themes.

    .DESCRIPTION
        Single source of truth for the location of a bundled theme (Assets/Themes/<Name>.omp.json),
        reused by Enable-OhMyPosh, Initialize-PwshProfile, Get-OhMyPoshTheme, and Export-OhMyPoshTheme
        so the path is resolved one way. $PSScriptRoot here is Private/Prompt/, so '..\..' reaches the
        module root and 'Assets/Themes' the theme folder beneath it.

        The path is returned whether or not the file exists; callers decide how to handle a missing
        file (Enable-OhMyPosh falls back to oh-my-posh's own default; the Get/Export functions
        throw a clear error).

    .PARAMETER Name
        The bundled theme to resolve, without the .omp.json suffix (e.g. 'screwcity'). Defaults to
        'screwcity', the module's original theme. Run Get-BundledThemeName for the full list of
        bundled themes.

    .EXAMPLE
        $theme = Get-BundledThemePath

        Returns the path to the default 'screwcity' theme.

    .EXAMPLE
        $theme = Get-BundledThemePath -Name forestcity

        Returns the path to the 'forestcity' (Forest City) theme.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Name = 'screwcity'
    )

    Join-Path $PSScriptRoot '..' '..' 'Assets' 'Themes' "$Name.omp.json"
}
