function Set-WindowsTerminalFont {
    <#
    .SYNOPSIS
        Sets the default profile font face in Windows Terminal's settings.json.

    .DESCRIPTION
        Points profiles.defaults.font.face in the user's Windows Terminal settings.json at a given
        font family, so every profile renders with it — handy right after installing a Nerd Font, so
        the oh-my-posh prompt glyphs (folder, git, OS icons) show up instead of boxes. The default
        font face is 'MesloLGM Nerd Font', the installed family name of the Meslo Nerd Font the
        install wizard offers.

        The edit is idempotent: re-running just overwrites the same face. The original settings.json is
        backed up to '<settings.json>.bak' before the rewrite. Supports -WhatIf / -Confirm.

        If Windows Terminal's settings.json can't be found (Windows Terminal not installed, or never
        launched), a warning is emitted and nothing is changed. Pass -SettingsPath to point at a
        specific file.

        JSONC note: settings.json may contain // comments; the parse -> rewrite round-trip does not
        preserve comments or hand-formatting (the .bak backup is the safety net).

    .PARAMETER FontFace
        The font family name to set as profiles.defaults.font.face. Defaults to 'MesloLGM Nerd Font'.
        Use the exact family name as it appears installed (for the Meslo Nerd Font that is
        'MesloLGM Nerd Font', not 'Menlo' or 'Meslo').

    .PARAMETER SettingsPath
        Optional path to the Windows Terminal settings.json to edit. Defaults to the first existing
        of the stable, preview, and unpackaged install locations (Get-WindowsTerminalSettingsPath).

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

    if (-not $SettingsPath) {
        $SettingsPath = Get-WindowsTerminalSettingsPath
    }
    if (-not $SettingsPath -or -not (Test-Path -LiteralPath $SettingsPath -PathType Leaf)) {
        Write-Warning "Set-WindowsTerminalFont: Windows Terminal settings.json not found. Is Windows Terminal installed and launched at least once? Pass -SettingsPath to override."
        return
    }

    if ($PSCmdlet.ShouldProcess($SettingsPath, "Set Windows Terminal default font to '$FontFace'")) {
        $null = Edit-WindowsTerminalSettings -Path $SettingsPath -FontFace $FontFace
        Write-Host "Set Windows Terminal default font to '$FontFace' in $SettingsPath (backup: $SettingsPath.bak). Restart Windows Terminal if it's open."
    }
}
