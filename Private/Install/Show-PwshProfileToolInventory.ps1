function Show-PwshProfileToolInventory {
    <#
    .SYNOPSIS
        Renders the tool inventory as a panel — a check for each tool already present, a down-arrow
        for each one the install is about to fetch.

    .DESCRIPTION
        Display-only. Turns Get-PwshProfileToolInventory's rows into a rounded panel so the install
        phase says what it is about to do, instead of collapsing into one summary line with no
        indication of what was already there.

        MUST be called BEFORE Invoke-Step opens the install step, never inside it. Writing to the host
        while a step's spinner is live tears the render — the same hazard Install-PwshProfile already
        works around with `6> $null` on two of its other steps.

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
        Panel border and glyph color. Defaults to the installer's fixed accent, which is intentionally
        decoupled from the prompt theme being configured.

    .EXAMPLE
        Show-PwshProfileToolInventory

        Probes the catalog and renders the panel.

    .EXAMPLE
        Show-PwshProfileToolInventory -Tool $inventory

        Renders an inventory already gathered, avoiding a second PATH walk.

    .NOTES
        Format-SpectrePanel emits its rendered string to the PIPELINE rather than the console, so the
        `| Out-Host` is load-bearing: without it the panel leaks into the caller's return value. The
        wizard has a regression test for exactly that leak.
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
        $lines = @(
            foreach ($row in $rows) {
                # Pad BEFORE escaping: escaping can lengthen the string (a '[' doubles), so padding
                # afterwards would count escape characters and misalign the state column.
                $label = Get-SpectreEscapedTextSafe -Text ("$($row.Label)".PadRight($width))
                if ($row.Installed) { "  [$Color]✓[/] $label  [grey]already installed[/]" }
                else { "  [$Color]↓[/] $label  [grey]will install[/]" }
            }
            ''
            "  [grey]$count[/]"
        ) -join [Environment]::NewLine

        $lines | Format-SpectrePanel -Header '◆ Tools' -Border Rounded -Color $Color -Expand | Out-Host
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
