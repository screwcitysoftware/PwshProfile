function Write-Figlet {
    <#
    .SYNOPSIS
        Renders text as figlet (large ASCII) art via PwshSpectreConsole, optionally in a bundled or
        custom FIGlet font.

    .DESCRIPTION
        A general-purpose figlet writer. Initialize-PwshProfile uses it for the startup banner, but it
        is not banner-specific — call it anywhere you want big ASCII text.

        Pass -Font to pick one of the module's bundled fonts (tab-completes) or -FontPath for any .flf
        of your own; the two are mutually exclusive. The bundled fonts span sizes, so you can match the
        font to the message length — Small for long strings, Colossal or ANSIShadow for short punchy
        ones. Run Show-FigletFont to list them, or Show-FigletFont -Preview to render samples.

        It writes only the figlet text, with no trailing blank line; add your own spacing if you want a
        gap after it. Without PwshSpectreConsole it returns silently rather than throwing, and a missing
        bundled font file warns and falls back to the default.

    .PARAMETER Text
        The text to render as figlet. Required.

    .PARAMETER Color
        Any Spectre color name or hex. Defaults to '#c9aaff', the module's signature purple.
        Initialize-PwshProfile overrides it with the selected theme's BannerColor.

    .PARAMETER Alignment
        'Left' (default), 'Center', or 'Right'.

    .PARAMETER Font
        A bundled FIGlet font (tab-completes; run Show-FigletFont to list them). Defaults to
        'ANSIShadow'. Mutually exclusive with -FontPath.

    .PARAMETER FontPath
        Path to a custom .flf font file, validated to exist at call time. Mutually exclusive with -Font.
        Not every .flf loads under Spectre's parser; if rendering fails, try another file.

    .EXAMPLE
        Write-Figlet 'Screw City'

        Renders "Screw City" in the ANSI Shadow font, in the theme's purple, left-aligned.

    .EXAMPLE
        Write-Figlet 'DEPLOY' -Font ANSIShadow -Color Green -Alignment Center

        Renders a centered green "DEPLOY" in the large ANSI Shadow block font.

    .EXAMPLE
        Write-Figlet 'A longer status message' -Font Small

        Uses the compact Small font so a long string still fits the terminal width.

    .EXAMPLE
        Write-Figlet 'Hi' -FontPath ~/.fonts/custom.flf

        Renders with a custom .flf font supplied by the caller.

    .NOTES
        Out-Host is required: the figlet widget emits its rendered ANSI string to the pipeline rather
        than writing to the console, so it is forced to the host directly.
    #>
    [CmdletBinding(DefaultParameterSetName = 'BundledFont')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Text,

        [Parameter()]
        [string]$Color = '#c9aaff',

        [Parameter()]
        [ValidateSet('Left', 'Center', 'Right')]
        [string]$Alignment = 'Left',

        [Parameter(ParameterSetName = 'BundledFont')]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                # Completers run in the caller's scope, where Get-BundledFontName isn't visible.
                Show-FigletFont | Where-Object { $_ -like "$wordToComplete*" } |
                    ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
            })]
        [ValidateScript({ $_ -in (Get-BundledFontName) },
            ErrorMessage = "'{0}' is not a bundled font. Run Show-FigletFont to list the available fonts.")]
        [string]$Font = 'ANSIShadow',

        [Parameter(ParameterSetName = 'CustomFont')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf },
            ErrorMessage = "FontPath '{0}' does not exist (expected a path to a .flf FIGlet font file).")]
        [string]$FontPath
    )

    # Failure tolerance: if PwshSpectreConsole isn't loaded, render nothing (don't throw).
    if (-not (Get-Command Write-SpectreFigletText -ErrorAction SilentlyContinue)) { return }

    # Resolve the requested font to a .flf path, if any.
    $resolvedFontPath = $null
    if ($PSCmdlet.ParameterSetName -eq 'BundledFont') {
        $resolvedFontPath = Get-BundledFontPath -Name $Font
        if (-not (Test-Path -Path $resolvedFontPath)) {
            # A missing bundled file is a packaging bug, not a caller error — warn and fall back
            # rather than letting Spectre throw out of profile startup.
            Write-Warning "Write-Figlet: bundled font '$Font' not found at '$resolvedFontPath'; using the default font."
            $resolvedFontPath = $null
        }
    } elseif ($PSCmdlet.ParameterSetName -eq 'CustomFont') {
        $resolvedFontPath = $FontPath
    }

    $figlet = @{ Color = $Color; Alignment = $Alignment }
    if ($resolvedFontPath) { $figlet.FigletFontPath = $resolvedFontPath }

    Write-SpectreFigletText $Text @figlet | Out-Host
}
