function Get-OhMyPoshTheme {
    <#
    .SYNOPSIS
        Emits the JSON of one of the module's bundled oh-my-posh themes.

    .DESCRIPTION
        Reads a bundled theme (Assets/Themes/<Theme>.omp.json) and writes its raw JSON to the
        pipeline. At a prompt this prints the theme; it can equally be piped to the clipboard, a
        file, or an editor as a starting point for customization.

        It deliberately emits the *content*, never the bundled file's path: when installed from a
        repository the module lives in a versioned, possibly read-only directory, and editing that
        copy in place would be lost on the next update. To produce an editable copy, pipe this to a
        file or use Export-OhMyPoshTheme, then point Enable-OhMyPosh -Configuration at it.

        Throws if the bundled theme is missing. Unlike the startup path, this is invoked
        interactively, so a terminating error is preferable to a silent no-op.

    .PARAMETER Theme
        The bundled theme to emit (tab-completes): the default 'screwcity', or any bundled theme
        (run Get-BundledThemeName for the full set).

    .EXAMPLE
        Get-OhMyPoshTheme

        Prints the default 'screwcity' theme's JSON to the console.

    .EXAMPLE
        Get-OhMyPoshTheme -Theme forestcity | Set-Content ~/my.omp.json

        Saves a copy of the Forest City theme to customize, then activate with
        Enable-OhMyPosh -Configuration ~/my.omp.json.

    .EXAMPLE
        Get-OhMyPoshTheme | clip

        Copies the theme JSON to the Windows clipboard.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
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
        [string]$Theme = 'screwcity'
    )

    $themePath = Get-BundledThemePath -Name $Theme
    if (-not (Test-Path -Path $themePath)) {
        throw "Get-OhMyPoshTheme: bundled theme not found at '$themePath'."
    }

    Get-Content -Path $themePath -Raw
}
