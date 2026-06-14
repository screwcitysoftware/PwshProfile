function Show-FigletFont {
    <#
    .SYNOPSIS
        Lists the module's bundled FIGlet font names, or renders samples of them.

    .DESCRIPTION
        Surfaces the FIGlet fonts bundled with the module so you can pick one for Write-Figlet
        (or Initialize-PwshProfile -BannerFont). By default it returns the bundled font names
        (the values accepted by Write-Figlet -Font) as plain strings — handy at a prompt or for
        scripting. The on-disk paths are intentionally not surfaced: the fonts ship inside the
        module, so the paths aren't useful to callers.

        Pass -Preview to render a labelled sample of each font instead of listing names. Use -Font
        to scope either mode to specific fonts, and -Text to render your own string in the preview
        instead of each font's name.

        Preview rendering goes through Write-Figlet and is guarded by PwshSpectreConsole's
        availability — if Spectre isn't loaded it renders nothing rather than throwing.

    .PARAMETER Font
        One or more bundled fonts to act on (tab-completes). When omitted, all bundled fonts are
        used.

    .PARAMETER Preview
        Render a labelled sample of each font instead of listing the names.

    .PARAMETER Text
        Preview only: the text to render in each sample. When omitted, each font renders its own
        name (so the sample is self-labelling). Pass a fixed string to compare fonts on identical
        text. Ignored when listing names.

    .EXAMPLE
        Show-FigletFont

        Lists the bundled font names.

    .EXAMPLE
        Show-FigletFont -Preview

        Renders a labelled sample of every bundled font, each spelling out its own name.

    .EXAMPLE
        Show-FigletFont ANSIShadow, Colossal -Preview -Text 'Deploy'

        Previews just the two large fonts, both rendering the word "Deploy".

    .NOTES
        Font selection for actual output lives on Write-Figlet (-Font / -FontPath); this function
        is for discovering/choosing.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                # Completers run in the caller's scope; Show-FigletFont (no args) lists the names.
                Show-FigletFont | Where-Object { $_ -like "$wordToComplete*" } |
                    ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
            })]
        [ValidateScript({ $_ -in (Get-BundledFontName) },
            ErrorMessage = "'{0}' is not a bundled font. Run Show-FigletFont to list the available fonts.")]
        [string[]]$Font,

        [Parameter()]
        [switch]$Preview,

        [Parameter(Position = 1)]
        [string]$Text
    )

    # Which fonts: explicit -Font, else every bundled font (the directory is the source of truth).
    $names = if ($Font) { $Font } else { Get-BundledFontName }

    # Default: just list the names.
    if (-not $Preview) { return $names }

    # Failure tolerance: silently skip rendering if PwshSpectreConsole isn't loaded.
    if (-not (Get-Command Write-SpectreHost -ErrorAction SilentlyContinue)) { return }

    foreach ($name in $names) {
        $sample = if ($PSBoundParameters.ContainsKey('Text')) { $Text } else { $name }
        Write-SpectreHost "[grey]── $name ──[/]"
        # Render via -FontPath so previews work for any .flf present, not only known names.
        Write-Figlet -Text $sample -FontPath (Get-BundledFontPath -Name $name)
    }
}
