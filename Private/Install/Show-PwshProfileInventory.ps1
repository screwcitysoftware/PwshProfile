function Show-PwshProfileInventory {
    <#
    .SYNOPSIS
        Renders an inventory as indented rows — a check for each item already present, a down-arrow for
        each one setup is about to fetch, a dot for each one fetched only under some condition.

        Display-only. Turns Get-PwshProfileToolInventory's or Get-PwshProfileModuleInventory's rows into
        the same two-space-indent row style Read-PwshProfileSettingChange uses, so a wizard step can say
        what is about to land on the machine before asking its own questions.

    .DESCRIPTION
        Rows rather than a panel: this renders INSIDE a wizard step, under that step's own header panel,
        and a panel nested in a panel reads wrong. Writing rows directly also sidesteps the
        Format-SpectrePanel trap — that emits its rendered string to the pipeline, so it needs an
        Out-Host or it leaks into the caller's return value. Write-SpectreHost goes to the console.

        MUST NOT be called inside a running Invoke-Step: writing to the host while a spinner is live
        tears the render, the same hazard Install-PwshProfile works around with `6> $null` on two of
        its steps. The wizard runs before any step opens, so that is satisfied there.

        The glyphs are ✓ (present), ↓ (will install), and · (conditional), deliberately not ✗. A cross
        reads as a failure, and an item that simply has not been fetched yet on a clean machine is the
        expected state, not an error. ✓ already carries this meaning elsewhere in the wizard chrome
        (Write-PwshProfilePromptAnswer).

        A row may carry an optional Detail: the condition under which it is installed, shown in place of
        "will install" and marked with · instead of ↓. That keeps the list from promising an install
        that may never happen — DockerCompletion on a machine with no docker, say. Rows without the
        property are read safely through PSObject.Properties, so the tool rows need no Detail column
        just to satisfy Set-StrictMode.

        Labels are escaped with Get-SpectreEscapedTextSafe rather than run through
        Format-PwshProfileHelpMarkup: they are literal catalog values, and markup formatting is for
        authored help text, where a stray backtick or asterisk is meant as syntax. Detail IS authored
        help text, so it goes the other way and is formatted.

        A row may also carry an optional Url (the project's homepage or repo): when present, the
        escaped label is wrapped in a Spectre hyperlink span and THEN padded with plain spaces after
        the closing tag, rather than padded first like the no-link branch -- padding inside the span
        would put the trailing whitespace inside "[link=...]...[/]", which a real terminal renders as
        part of the clickable/underlined link. Never escape the assembled link-markup string itself,
        either: escaping doubles brackets and would corrupt the markup rather than the (already-safe)
        label text inside it. The plain-text fallback has no markup at all, so it appends the raw URL
        as visible text instead.

        Degrades like Show-NerdFontSetup — a plain Write-Host when Spectre isn't available.

    .PARAMETER Row
        The inventory rows to render, as produced by Get-PwshProfileToolInventory or
        Get-PwshProfileModuleInventory: each needs a Label and an Installed bool, and may carry a
        Detail. Defaults to the tool inventory, so the common case is a bare invocation.

    .PARAMETER Color
        Glyph color. Defaults to the installer's fixed accent, which is intentionally decoupled from
        the prompt theme being configured.

    .EXAMPLE
        Show-PwshProfileInventory

        Probes the tool catalog and renders the rows.

    .EXAMPLE
        Show-PwshProfileInventory -Row (Get-PwshProfileModuleInventory)

        Renders the gallery modules instead, conditions and all.

    .NOTES
        Called from the wizard's Winget and Modules steps, which is where the plan is most useful:
        before the review screen, and next to the settings it explains the need for. The apply phase
        reports actuals instead, one top-level Invoke-Step per package it genuinely installs.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [object[]]$Row,

        [Parameter()]
        [string]$Color = '#c9aaff'
    )

    $rows = @(if ($PSBoundParameters.ContainsKey('Row')) { $Row } else { Get-PwshProfileToolInventory })
    if ($rows.Count -eq 0) { return }

    # A row's Detail/Url are optional, so read them through PSObject.Properties -- a missing property
    # throws under Set-StrictMode -Version Latest, and hand-built test rows deliberately omit them.
    function Get-RowDetail {
        param($InventoryRow)
        $p = $InventoryRow.PSObject.Properties['Detail']
        if ($p) { "$($p.Value)" } else { '' }
    }
    function Get-RowUrl {
        param($InventoryRow)
        $p = $InventoryRow.PSObject.Properties['Url']
        if ($p) { "$($p.Value)" } else { '' }
    }

    $present = @($rows | Where-Object { $_.Installed })
    $pending = @($rows | Where-Object { -not $_.Installed -and -not (Get-RowDetail $_) })
    $conditional = @($rows | Where-Object { -not $_.Installed -and (Get-RowDetail $_) })

    # Pad the labels so the state column lines up, the way the review panel aligns its own rows.
    $width = ($rows | ForEach-Object { "$($_.Label)".Length } | Measure-Object -Maximum).Maximum

    $count = if ($pending.Count -eq 0 -and $conditional.Count -eq 0) { "all $($rows.Count) already installed" }
    else {
        @(
            if ($present.Count -gt 0) { "$($present.Count) present" }
            if ($pending.Count -gt 0) { "$($pending.Count) to install" }
            if ($conditional.Count -gt 0) { "$($conditional.Count) only if needed" }
        ) -join ' · '
    }

    if (Get-Command Write-SpectreHost -ErrorAction SilentlyContinue) {
        foreach ($r in $rows) {
            $rawLabel = "$($r.Label)"
            $url = Get-RowUrl $r
            if ($url) {
                # Pad OUTSIDE the link span with plain spaces, keyed to the unescaped label's length --
                # padding the label before wrapping (as the no-link branch does) would put the trailing
                # whitespace INSIDE "[link=...]...[/]", and a real terminal renders that whitespace as
                # part of the clickable/underlined link.
                $label = "[link=$url]$(Get-SpectreEscapedTextSafe -Text $rawLabel)[/]" + (' ' * ($width - $rawLabel.Length))
            }
            else {
                # Pad BEFORE escaping: escaping can lengthen the string (a '[' doubles), so padding
                # afterwards would count escape characters and misalign the state column.
                $label = Get-SpectreEscapedTextSafe -Text ($rawLabel.PadRight($width))
            }
            $detail = Get-RowDetail $r
            if ($r.Installed) { Write-SpectreHost "  [$Color]✓[/] $label  [grey]already installed[/]" }
            elseif ($detail) {
                Write-SpectreHost "  [grey]·[/] $label  $(Format-PwshProfileHelpMarkup -Text $detail -Accent $Color)"
            }
            else { Write-SpectreHost "  [$Color]↓[/] $label  [grey]will install[/]" }
        }
        # The count stays attached to the rows it summarizes; the trailing blank separates the whole
        # block from whatever the caller prints next -- in the Winget step, its settings rows.
        Write-SpectreHost "  [grey]$count[/]"
        Write-SpectreHost ''
    }
    else {
        $plain = @(
            foreach ($r in $rows) {
                $detail = Get-RowDetail $r
                $url = Get-RowUrl $r
                $mark = if ($r.Installed) { '[installed]' } elseif ($detail) { $detail } else { '[will install]' }
                # No markup in this fallback, so the URL rides along as plain visible text instead.
                "  $("$($r.Label)".PadRight($width))  $mark$(if ($url) { "  <$url>" })"
            }
            "  $count"
            ''
        ) -join [Environment]::NewLine
        Write-Host $plain
    }
}
