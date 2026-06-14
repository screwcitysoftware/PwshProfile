function Get-BundledThemeName {
    <#
    .SYNOPSIS
        Returns the names of the oh-my-posh themes bundled with the module.

    .DESCRIPTION
        The single source of truth for which themes are available: enumerates Assets/Themes/*.omp.json
        and returns their sorted names with the '.omp.json' suffix stripped. These are the values
        accepted by Initialize-PwshProfile -Theme (and offered as the bundled choices in the
        Install-PwshProfile wizard).

        Drives the dynamic -Theme validation and tab-completion, so dropping a new <name>.omp.json in
        Assets/Themes changes the accepted set with no code edits. Returns nothing if the folder is
        missing (callers degrade rather than throw).

        Note: a theme file is '<name>.omp.json', so its base name is '<name>.omp' — the '.omp.json'
        suffix is trimmed from the file Name rather than relying on BaseName.

    .EXAMPLE
        Get-BundledThemeName

        Returns e.g. forestcity, screwcity (one per bundled .omp.json).
    #>
    [CmdletBinding()]
    param()

    $dir = Join-Path $PSScriptRoot '..' '..' 'Assets' 'Themes'
    Get-ChildItem -Path $dir -Filter *.omp.json -ErrorAction SilentlyContinue |
        Sort-Object Name |
        ForEach-Object { $_.Name -replace '\.omp\.json$', '' }
}
