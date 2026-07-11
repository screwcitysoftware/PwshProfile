function Write-PwshProfileStepHeader {
    <#
    .SYNOPSIS
        Renders the rounded per-step header panel for the Install-PwshProfile wizard.

    .DESCRIPTION
        Each wizard step opens with one of these panels instead of a bare rule: a rounded, accent-bordered
        box whose header carries a diamond glyph, the step title, and a "N of M" progress counter, and
        whose body is the step's primary description run through Format-PwshProfileHelpMarkup (so tool
        names and code literals are highlighted rather than flat grey).

        A blank line is emitted first to separate the panel from whatever the previous step left on
        screen, giving the wizard some vertical rhythm.

        Like the rest of the wizard chrome this is guarded on Format-SpectrePanel and silently no-ops
        when Spectre is unavailable. Format-SpectrePanel emits its rendered string to the pipeline (it
        does not write to the console), so the panel is piped to Out-Host — without that it would leak
        into the caller's return value, exactly the hazard the wizard documents for Write-SpectreRule.

    .PARAMETER Title
        The step title shown in the panel header (e.g. 'Theme', 'Banner', 'Features').

    .PARAMETER Index
        The 1-based position of this step, shown as the left side of the "N of M" counter.

    .PARAMETER Total
        The total number of steps, shown as the right side of the "N of M" counter.

    .PARAMETER Body
        The step's primary description. Authored in the Format-PwshProfileHelpMarkup convention
        (**brand** / `code`); highlighted before rendering.

    .PARAMETER Accent
        The accent color for the panel border and **...** spans. Defaults to the module's signature
        purple (#c9aaff).

    .PARAMETER Code
        The color for `...` code-literal spans in the body. Defaults to a soft cyan (#5fd7ff).

    .EXAMPLE
        Write-PwshProfileStepHeader -Title 'Theme' -Index 1 -Total 5 `
            -Body '**oh-my-posh** draws your prompt. Pick a bundled look or your own `.omp.json`.'

        Prints a blank line, then a rounded panel headed '◆ Theme · 1 of 5' with the highlighted
        description inside.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Title,

        [Parameter(Mandatory)]
        [int]$Index,

        [Parameter(Mandatory)]
        [int]$Total,

        [Parameter()]
        [string]$Body,

        [Parameter()]
        [string]$Accent = '#c9aaff',

        [Parameter()]
        [string]$Code = '#5fd7ff'
    )

    if (-not (Get-Command Format-SpectrePanel -ErrorAction SilentlyContinue)) { return }

    if (Get-Command Write-SpectreHost -ErrorAction SilentlyContinue) { Write-SpectreHost '' }

    # Header color comes from the panel border, so it stays plain text (no markup-in-header surprises).
    # Spectre trims header whitespace, so it renders flush against the corner dashes (╭─◆ Theme · 1 of 5─).
    $header = "◆ $Title · $Index of $Total"
    $content = Format-PwshProfileHelpMarkup -Text $Body -Accent $Accent -Code $Code

    $content | Format-SpectrePanel -Header $header -Border Rounded -Color $Accent -Expand | Out-Host
}
