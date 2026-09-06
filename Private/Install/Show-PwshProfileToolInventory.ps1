function Show-PwshProfileToolInventory {
    <#
    .SYNOPSIS
        Renders the tool inventory as indented rows — a check for each tool already present, a
        down-arrow for each one setup is about to fetch.

        Display-only. Turns Get-PwshProfileToolInventory's rows into the same two-space-indent row
        style Read-PwshProfileSettingChange uses, so the wizard's Winget step can say what winget is
        about to install before asking about winget's settings.

    .DESCRIPTION
        Rows rather than a panel: this renders INSIDE the Winget step, under that step's own header
        panel, and a panel nested in a panel reads wrong. Writing rows directly also sidesteps the
        Format-SpectrePanel trap — that emits its rendered string to the pipeline, so it needs an
        Out-Host or it leaks into the caller's return value. Write-SpectreHost goes to the console.

        MUST NOT be called inside a running Invoke-Step: writing to the host while a spinner is live
        tears the render, the same hazard Install-PwshProfile works around with `6> $null` on two of
        its steps. The wizard runs before any step opens, so that is satisfied there.

        The glyphs are ✓ (present) and ↓ (will install), deliberately not ✗. A cross reads as a
        failure, and a tool that simply has not been fetched yet on a clean machine is the expected
        state, not an error. ✓ already carries this meaning elsewhere in the wizard chrome
        (Write-PwshProfilePromptAnswer).

        Labels are escaped with Get-SpectreEscapedTextSafe rather than run through
        Format-PwshProfileHelpMarkup: they are literal catalog values, and markup formatting is for
        authored help text, where a stray backtick or asterisk is meant as syntax.

        Degrades like Show-NerdFontSetup — a plain Write-Host when Spectre isn't available.

    .PARAMETER Tool
        The inventory rows to render, as produced by Get-PwshProfileToolInventory. Defaults to
        calling it, so the common case is a bare invocation.

    .PARAMETER Color
        Glyph color. Defaults to the installer's fixed accent, which is intentionally decoupled from
        the prompt theme being configured.

    .EXAMPLE
        Show-PwshProfileToolInventory

        Probes the catalog and renders the rows.

    .EXAMPLE
        Show-PwshProfileToolInventory -Tool $inventory

        Renders an inventory already gathered, avoiding a second PATH walk.

    .NOTES
        Called from the wizard's Winget step, which is where the plan is most useful: before the
        review screen, and next to the winget settings it explains the need for. The apply phase
        reports actuals instead, one top-level Invoke-Step per package it genuinely installs.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [object[]]$Tool,

        [Parameter()]
        [string]$Color = '#c9aaff'
    )

    $rows = @(if ($PSBoundParameters.ContainsKey('Tool')) { $Tool } else { Get-PwshProfileToolInventory })
    if ($rows.Count -eq 0) { return }

    $present = @($rows | Where-Object { $_.Installed })
    $missing = @($rows | Where-Object { -not $_.Installed })

    # Pad the labels so the state column lines up, the way the review panel aligns its own rows.
    $width = ($rows | ForEach-Object { "$($_.Label)".Length } | Measure-Object -Maximum).Maximum

    $count = if ($missing.Count -eq 0) { "all $($rows.Count) already installed" }
    else { "$($present.Count) present · $($missing.Count) to install" }

    if (Get-Command Write-SpectreHost -ErrorAction SilentlyContinue) {
        foreach ($row in $rows) {
            # Pad BEFORE escaping: escaping can lengthen the string (a '[' doubles), so padding
            # afterwards would count escape characters and misalign the state column.
            $label = Get-SpectreEscapedTextSafe -Text ("$($row.Label)".PadRight($width))
            if ($row.Installed) { Write-SpectreHost "  [$Color]✓[/] $label  [grey]already installed[/]" }
            else { Write-SpectreHost "  [$Color]↓[/] $label  [grey]will install[/]" }
        }
        Write-SpectreHost "  [grey]$count[/]"
    }
    else {
        $plain = @(
            foreach ($row in $rows) {
                $mark = if ($row.Installed) { '[installed]' } else { '[will install]' }
                "  $("$($row.Label)".PadRight($width))  $mark"
            }
            ''
            "  $count"
        ) -join [Environment]::NewLine
        Write-Host $plain
    }
}
