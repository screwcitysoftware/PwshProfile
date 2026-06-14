function Show-NerdFontSetup {
    <#
    .SYNOPSIS
        Shows how to point Windows Terminal and VS Code at an installed Nerd Font.

    .DESCRIPTION
        Installing a Nerd Font isn't enough to render the oh-my-posh prompt glyphs — you also have to
        set your terminal's font to it. This renders a panel with the exact steps for Windows Terminal
        and VS Code. Install-PwshProfile shows it during setup (before writing the bootstrap), whether
        or not you installed fonts, but you can run it any time.

        A wrinkle this handles: the font *family* name you type into the terminal is not the catalog
        name you install. For example installing 'Meslo' gives the family 'MesloLGM Nerd Font', and
        'CascadiaCode' gives 'CaskaydiaCove Nerd Font'. Pass -Font with the catalog name(s) you
        installed and the panel names the matching families; with no -Font it shows the recommended
        pairing.

        If PwshSpectreConsole isn't available, the same text is written plainly instead of in a panel.

    .PARAMETER Font
        The Nerd Font catalog name(s) you installed (e.g. 'Meslo', 'CascadiaCode'), as accepted by
        Install-NerdFont. Known names are mapped to their terminal family name; unrecognized names
        fall back to the recommended pairing plus a generic note. When omitted, the recommended
        families are shown.

    .EXAMPLE
        Show-NerdFontSetup

        Shows the setup steps for the recommended families (MesloLGM Nerd Font, CaskaydiaCove Nerd Font).

    .EXAMPLE
        Show-NerdFontSetup -Font Meslo, CascadiaCode

        Shows the steps naming the families those two catalog fonts install as.

    .NOTES
        The '… Mono' family variants are strictly monospaced; the plain families include a few
        proportional glyphs. Restart the terminal after changing the font.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string[]]$Font
    )

    # Catalog name -> the font family you select in a terminal. Only the names the wizard offers are
    # mapped; anything else falls back to the recommended pairing rather than guessing a family name.
    $familyMap = @{
        Meslo        = 'MesloLGM Nerd Font'
        CascadiaCode = 'CaskaydiaCove Nerd Font'
        CascadiaMono = 'CaskaydiaCove Nerd Font Mono'
    }
    $recommended = @('MesloLGM Nerd Font', 'CaskaydiaCove Nerd Font')

    $requested = @($Font | Where-Object { $_ })
    $generic = $false
    $families = @()
    foreach ($f in $requested) {
        if ($familyMap.ContainsKey($f)) { $families += $familyMap[$f] } else { $generic = $true }
    }
    if ($families.Count -eq 0) {
        $families = $recommended
        if ($requested.Count -gt 0) { $generic = $true }
    }
    $families = @($families | Select-Object -Unique)
    $primary = $families[0]

    $lines = @(
        'Installing the font is only half of it — set your terminal''s font to a Nerd Font so the',
        'prompt glyphs render. The family name to pick differs from the install name:',
        ''
        "Families to choose:  $($families -join ', ')",
        ''
        'Windows Terminal'
        "  Settings (Ctrl+,) -> Profiles -> Defaults -> Appearance -> Font face -> $primary"
        "  or settings.json (profiles.defaults):  ""font"": { ""face"": ""$primary"" }"
        ''
        'VS Code'
        "  settings.json:  ""terminal.integrated.fontFamily"": ""$primary"""
        ''
        'Restart the terminal after changing the font. (For strictly monospaced glyphs, install the'
        'Mono variant too, e.g. Install-NerdFont -Name Meslo -Variant Mono, and pick its "… Mono" family.)'
    )
    if ($generic) {
        $lines += 'For any other Nerd Font, pick the family whose name ends in "Nerd Font" in the font picker.'
    }
    $text = $lines -join [Environment]::NewLine

    if (Get-Command Format-SpectrePanel -ErrorAction SilentlyContinue) {
        $text | Format-SpectrePanel -Header 'Terminal font setup' -Border Rounded -Color '#c9aaff' -Expand | Out-Host
    }
    else {
        Write-Host $text
    }
}
