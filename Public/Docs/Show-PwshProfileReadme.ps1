function Show-PwshProfileReadme {
    <#
    .SYNOPSIS
        Renders the module's README in the console, or opens it in your default Markdown app.

    .DESCRIPTION
        Locates the module's bundled README.md and renders it to the console with Show-Markdown
        (VT100/ANSI formatting), so the documentation is one command away from any session.

        Pass -Open to instead hand the file to the operating system's default handler for .md
        files (via Invoke-Item) — whatever editor or viewer you've associated with Markdown.

        Throws if the README can't be found. Unlike profile startup, this is invoked
        interactively, so a terminating error is preferable to a silent no-op.

    .PARAMETER Open
        Open the README in the default application registered for Markdown files instead of
        rendering it in the console.

    .EXAMPLE
        Show-PwshProfileReadme

        Renders the README in the console with Show-Markdown.

    .EXAMPLE
        Show-PwshProfileReadme -Open

        Opens README.md in your system's default Markdown application.

    .NOTES
        $PSScriptRoot here is Public/Docs/, so '..\..' reaches the module root where README.md lives.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Open
    )

    $readmePath = Join-Path $PSScriptRoot '..' '..' 'README.md'
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

    Show-Markdown -Path $readmePath
}
