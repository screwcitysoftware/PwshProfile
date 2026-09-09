function Show-PwshProfileReadme {
    <#
    .SYNOPSIS
        Renders the module's README in the console, or opens it in your default Markdown app.

    .DESCRIPTION
        Locates the module's bundled README.md and renders it to the console with Show-Markdown
        (VT100/ANSI formatting), so the documentation is one command away from any session.
        PowerShell's default Show-Markdown colors render badly in a real terminal (a reverse-video
        Header1 that inverts whatever the terminal's current colors are, and a hardcoded gray-
        background code block that fights the terminal's own background), so this applies the
        chosen bundled theme's MarkdownHeaderColor/MarkdownCodeColor (from Get-BundledThemeBranding)
        via Set-MarkdownOption first, then restores the session's prior markdown-rendering settings
        afterward — Set-MarkdownOption mutates process-wide state, so this command's own theming
        doesn't leak into some other Show-Markdown call later in the session.

        Pass -Open to instead hand the file to the operating system's default handler for .md
        files (via Invoke-Item) — whatever editor or viewer you've associated with Markdown. -Theme
        has no effect in that case, since it never touches markdown rendering.

        Throws if the README can't be found. Unlike profile startup, this is invoked
        interactively, so a terminating error is preferable to a silent no-op.

    .PARAMETER Theme
        The bundled theme whose header/code colors to render the README with (tab-completes): the
        default 'screwcity', or any bundled theme (run Get-BundledThemeName for the full set).

    .PARAMETER Open
        Open the README in the default application registered for Markdown files instead of
        rendering it in the console.

    .EXAMPLE
        Show-PwshProfileReadme

        Renders the README in the console with Show-Markdown, using the screwcity theme's colors.

    .EXAMPLE
        Show-PwshProfileReadme -Theme forestcity

        Renders the README using the Forest City theme's header/code colors.

    .EXAMPLE
        Show-PwshProfileReadme -Open

        Opens README.md in your system's default Markdown application.

    .NOTES
        The path hangs off $script:ModuleRoot (set once in the .psm1) rather than $PSScriptRoot, so it
        holds whether the module is dot-sourced per file or shipped as one merged .psm1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                # Completers run in the caller's scope; reach the shared completer through the module.
                # Select -Last 1: if more than one copy of the module is loaded (e.g. a dev checkout
                # alongside a staged build), Get-Module returns an array, and & can't invoke that.
                $module = Get-Module ScrewCitySoftware.PwshProfile | Select-Object -Last 1
                if ($module) { & $module { param($w) Get-BundledThemeCompletion -WordToComplete $w } $wordToComplete }
            })]
        [ValidateScript({ $_ -in (Get-BundledThemeName) },
            ErrorMessage = "'{0}' is not a bundled theme. Check Assets/Themes for the available themes.")]
        [string]$Theme = 'screwcity',

        [Parameter()]
        [switch]$Open
    )

    $readmePath = Join-Path $script:ModuleRoot 'README.md'
    if (-not (Test-Path -Path $readmePath)) {
        throw "Show-PwshProfileReadme: README not found at '$readmePath'."
    }
    # Resolve to an absolute path so the default app / Show-Markdown get a clean path, not one
    # with a '..' segment.
    $readmePath = (Resolve-Path -Path $readmePath).Path

    if ($Open) {
        Invoke-Item -Path $readmePath
        return
    }

    $branding = Get-BundledThemeBranding -Name $Theme
    $priorOption = Get-MarkdownOption
    try {
        Set-MarkdownOption -Header1Color $branding.MarkdownHeaderColor -Code $branding.MarkdownCodeColor
        Show-Markdown -Path $readmePath
    } finally {
        Set-MarkdownOption -InputObject $priorOption
    }
}
