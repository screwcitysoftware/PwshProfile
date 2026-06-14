function Export-OhMyPoshTheme {
    <#
    .SYNOPSIS
        Writes one of the module's bundled oh-my-posh themes to a file for customization.

    .DESCRIPTION
        Copies a bundled theme (Assets/Themes/<Theme>.omp.json) to a destination you own, so
        you can edit it and feed it back via Enable-OhMyPosh -Configuration <path>. The destination
        is mandatory; to view the theme on the console instead, use Get-OhMyPoshTheme.

        The destination is never the bundled file itself: when installed from a repository the
        module lives in a versioned, possibly read-only directory, and edits there would be lost on
        the next update. Export to a user-owned location and customize that copy.

        An existing destination is left untouched unless -Force is given. Supports -WhatIf and
        -Confirm. Throws if the bundled theme is missing.

    .PARAMETER Path
        Destination file path for the exported theme.

    .PARAMETER Theme
        The bundled theme to export (tab-completes): the default 'screwcity', or any bundled theme
        (run Get-BundledThemeName for the full set).

    .PARAMETER Force
        Overwrite the destination if it already exists.

    .EXAMPLE
        Export-OhMyPoshTheme -Path ~/my.omp.json

        Writes a copy of the default 'screwcity' theme to customize, then activate with
        Enable-OhMyPosh -Configuration ~/my.omp.json.

    .EXAMPLE
        Export-OhMyPoshTheme -Theme forestcity -Path ~/forest.omp.json -Force

        Overwrites ~/forest.omp.json with the bundled Forest City theme.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path,

        [Parameter(Position = 1)]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $base = (Get-Module ScrewCitySoftware.PwshProfile).ModuleBase
                if ($base) {
                    Get-ChildItem -Path (Join-Path $base 'Assets' 'Themes') -Filter *.omp.json -ErrorAction SilentlyContinue |
                        ForEach-Object { $_.Name -replace '\.omp\.json$', '' } |
                        Where-Object { $_ -like "$wordToComplete*" } |
                        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
                }
            })]
        [ValidateScript({ $_ -in (Get-BundledThemeName) },
            ErrorMessage = "'{0}' is not a bundled theme. Check Assets/Themes for the available themes.")]
        [string]$Theme = 'screwcity',

        [Parameter()]
        [switch]$Force
    )

    $themePath = Get-BundledThemePath -Name $Theme
    if (-not (Test-Path -Path $themePath)) {
        throw "Export-OhMyPoshTheme: bundled theme not found at '$themePath'."
    }

    # Copy-Item silently overwrites by default, so gate on existence ourselves: only -Force
    # may clobber an existing destination.
    if ((Test-Path -Path $Path) -and -not $Force) {
        throw "Export-OhMyPoshTheme: '$Path' already exists. Use -Force to overwrite."
    }

    if ($PSCmdlet.ShouldProcess($Path, 'Export oh-my-posh theme')) {
        Copy-Item -Path $themePath -Destination $Path -Force
    }
}
