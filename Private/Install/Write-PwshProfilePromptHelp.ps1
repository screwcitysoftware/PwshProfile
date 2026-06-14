function Write-PwshProfilePromptHelp {
    <#
    .SYNOPSIS
        Writes one or more dimmed context lines above an install-wizard prompt.

    .DESCRIPTION
        The PwshSpectreConsole prompt cmdlets (Read-SpectreText / Read-SpectreSelection /
        Read-SpectreConfirm / Read-SpectreMultiSelection) render only their -Message line — they have
        no description field. To give the Install-PwshProfile wizard's choices some context for users
        who aren't already familiar with the tools, call this helper immediately before a prompt (or to
        carry a step's secondary/inline hints, beneath its header panel) to print a short explanation.

        Each line is prefixed with a dim accent '›' glyph and run through Format-PwshProfileHelpMarkup,
        so the body reads as soft grey while **tool names** are accented and `code literals` are tinted
        — and any literal Spectre markup characters ('[' / ']') in the text are escaped, not
        interpreted. The whole thing is guarded on Write-SpectreHost, so it silently no-ops in the
        non-interactive / Spectre-unavailable path — matching the wizard's degraded-mode fallback
        elsewhere.

    .PARAMETER Line
        One or more help lines to print, in order. Use the Format-PwshProfileHelpMarkup convention —
        **term** for tool/product names and `code` for file types/commands/paths; everything else is
        plain body text (and markup characters are escaped, not interpreted).

    .PARAMETER Accent
        The accent color for the leading glyph and **...** spans, as a Spectre color name or hex value.
        Defaults to the module's signature purple (#c9aaff).

    .PARAMETER Code
        The color for `...` code-literal spans, as a Spectre color name or hex value. Defaults to a
        soft cyan (#5fd7ff).

    .EXAMPLE
        Write-PwshProfilePromptHelp '**zoxide** is a smarter `cd` that learns your most-used directories.'
        $cmd = Read-SpectreText -Message "zoxide's jump command (replaces cd)" -DefaultAnswer 'cd'

        Prints the highlighted context line, then shows the prompt beneath it.

    .EXAMPLE
        Write-PwshProfilePromptHelp 'First line of context.', 'Second line of context.'

        Prints two lines, one per array element, each with the leading glyph.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string[]]$Line,

        [Parameter()]
        [string]$Accent = '#c9aaff',

        [Parameter()]
        [string]$Code = '#5fd7ff'
    )

    if (-not (Get-Command Write-SpectreHost -ErrorAction SilentlyContinue)) { return }

    foreach ($text in $Line) {
        $body = Format-PwshProfileHelpMarkup -Text "$text" -Accent $Accent -Code $Code
        Write-SpectreHost "  [$Accent]›[/] $body"
    }
}
