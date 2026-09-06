function Get-WindowsTerminalSchemeName {
    <#
    .SYNOPSIS
        Returns the names of the color schemes present in Windows Terminal's settings.json.

    .DESCRIPTION
        A read-only lister, unlike Resolve-WindowsTerminalSettingsPath's other callers
        (Install-WindowsTerminalScheme, Uninstall-WindowsTerminalScheme, Set-WindowsTerminalFont), all
        of which mutate settings.json. This exists so a caller can ask "is a given scheme actually
        installed?" without editing anything and without a warning for the ordinary case of Windows
        Terminal not being installed at all.

        Failure-tolerant by design: returns an empty array, silently, whenever there is nothing to
        report — no settings.json found, or one that fails to parse — rather than throwing or warning.
        "Windows Terminal isn't installed" is not a failure.

    .PARAMETER SettingsPath
        Optional path to the Windows Terminal settings.json to read. Defaults to the first existing of
        the stable, preview, and unpackaged install locations (Get-WindowsTerminalSettingsPath).

    .EXAMPLE
        if ('Screw City' -in (Get-WindowsTerminalSchemeName)) { ... }

        Checks whether the bundled screwcity scheme has actually been installed.

    .NOTES
        Deliberately silent on every "nothing to report" path — the two mutating WT commands warn
        because a caller asked them to change something specific; this only ever answers "what's
        there", so callers use it before deciding whether to offer that specific change at all.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter()]
        [string]$SettingsPath
    )

    if (-not $SettingsPath) {
        $SettingsPath = Get-WindowsTerminalSettingsPath
    }
    if (-not $SettingsPath -or -not (Test-Path -LiteralPath $SettingsPath -PathType Leaf)) {
        return @()
    }

    try {
        $settings = Get-Content -LiteralPath $SettingsPath -Raw | ConvertFrom-Json
    }
    catch {
        return @()
    }

    @($settings.schemes.name)
}
