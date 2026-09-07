function Set-WindowsTerminalFont {
    <#
    .SYNOPSIS
        Sets the default profile font face in Windows Terminal's settings.json.

    .DESCRIPTION
        Points profiles.defaults.font.face at a given font family so every profile renders with it —
        handy right after installing a Nerd Font, so the oh-my-posh prompt glyphs show up instead of
        boxes. The default is 'MesloLGM Nerd Font', the installed family name of the Meslo Nerd Font the
        install wizard offers.

        The edit is idempotent, and settings.json is backed up to '<settings.json>.bak' first, since the
        parse-then-rewrite round-trip does not preserve // comments or hand-formatting. Supports
        -WhatIf / -Confirm. If settings.json can't be found (Windows Terminal not installed, or never
        launched), a warning is emitted and nothing changes.

    .PARAMETER FontFace
        The font family to set. Defaults to 'MesloLGM Nerd Font'. Use the exact family name as
        installed — for Meslo that is 'MesloLGM Nerd Font', not 'Menlo' or 'Meslo'.

    .PARAMETER SettingsPath
        Optional path to the settings.json to edit. Defaults to the first existing of the stable,
        preview, and unpackaged install locations.

    .EXAMPLE
        Set-WindowsTerminalFont

        Sets 'MesloLGM Nerd Font' as the default font for all Windows Terminal profiles.

    .EXAMPLE
        Set-WindowsTerminalFont -FontFace 'CaskaydiaCove Nerd Font'

        Sets the Cascadia Code Nerd Font family as the default profile font.

    .EXAMPLE
        Set-WindowsTerminalFont -WhatIf

        Shows what would change without writing.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interactive confirmation for a user-invoked command — same intent as Install-WindowsTerminalScheme. The result is host feedback, not pipeline data.')]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$FontFace = 'MesloLGM Nerd Font',

        [Parameter()]
        [string]$SettingsPath
    )

    $SettingsPath = Resolve-WindowsTerminalSettingsPath -Path $SettingsPath -CallerName 'Set-WindowsTerminalFont'
    if (-not $SettingsPath) { return }

    if ($PSCmdlet.ShouldProcess($SettingsPath, "Set Windows Terminal default font to '$FontFace'")) {
        $null = Edit-WindowsTerminalSettings -Path $SettingsPath -FontFace $FontFace
        Write-Host "Set Windows Terminal default font to '$FontFace' in $SettingsPath (backup: $SettingsPath.bak). Restart Windows Terminal if it's open."
    }
}
