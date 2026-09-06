function Get-PwshProfileConsoleWidth {
    <#
    .SYNOPSIS
        The current console's window width, or a safe fallback when it can't be read.

    .DESCRIPTION
        Show-PwshProfileChord hand-wraps its detail text to this width with a hanging indent, rather
        than letting the terminal (or Format-SpectrePanel's own wrap) break a long line wherever it
        likes — which loses the indent and makes the continuation read as an unrelated new line.

        $Host.UI.RawUI.WindowSize throws, or returns a useless value, under a redirected or
        non-interactive host (Pester, a piped invocation). This is a separate function rather than an
        inline try/catch so a caller has something mockable instead of touching $Host directly.

    .EXAMPLE
        Get-PwshProfileConsoleWidth

        The window width, or 80 when it can't be determined.
    #>
    [CmdletBinding()]
    param()

    try {
        $width = $Host.UI.RawUI.WindowSize.Width
        if ($width -gt 0) { return $width }
    }
    catch {
        # Non-interactive/redirected host (e.g. Pester): fall through to the fallback below.
        $null = $_
    }
    80
}
