function Uninstall-WindowsTerminalScheme {
    <#
    .SYNOPSIS
        Removes a bundled theme's color scheme from Windows Terminal's settings.json.

    .DESCRIPTION
        Reverses Install-WindowsTerminalScheme: removes the color scheme whose name matches a bundled
        theme's display name ('Screw City' / 'Forest City') from the user's settings.json `schemes`
        array. The original settings.json is backed up to '<settings.json>.bak' before the rewrite.
        Supports -WhatIf / -Confirm.

        It does not touch profiles' colorScheme references — if the removed scheme was still set as a
        profile's (or the defaults') active color scheme, a warning points that out so you can pick a
        replacement in Windows Terminal (leaving a dangling reference makes Windows Terminal fall back
        to its built-in default).

        If the scheme isn't present (or settings.json can't be found), a warning is emitted and
        nothing is changed. Pass -SettingsPath to point at a specific file.

    .PARAMETER Theme
        The bundled theme whose scheme to remove (tab-completes): the default 'screwcity', or any
        bundled theme (run Get-BundledThemeName for the full set). The scheme is matched by the
        theme's display name.

    .PARAMETER SettingsPath
        Optional path to the Windows Terminal settings.json to edit. Defaults to the first existing
        of the stable, preview, and unpackaged install locations (Get-WindowsTerminalSettingsPath).

    .EXAMPLE
        Uninstall-WindowsTerminalScheme

        Removes the 'Screw City' color scheme from settings.json.

    .EXAMPLE
        Uninstall-WindowsTerminalScheme -Theme forestcity -WhatIf

        Shows that the 'Forest City' scheme would be removed, without writing.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interactive confirmation for a user-invoked command — same intent as Show-NerdFontSetup (which the rule exempts only by its Show- verb). The result is host feedback, not pipeline data.')]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0)]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                # Completers run in the caller's scope, so reach the private lister through the module.
                $module = Get-Module ScrewCitySoftware.PwshProfile
                if ($module) {
                    & $module { Get-BundledThemeName } |
                        Where-Object { $_ -like "$wordToComplete*" } |
                        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
                }
            })]
        [ValidateScript({ $_ -in (Get-BundledThemeName) },
            ErrorMessage = "'{0}' is not a bundled theme. Check Assets/Themes for the available themes.")]
        [string]$Theme = 'screwcity',

        [Parameter()]
        [string]$SettingsPath
    )

    $SettingsPath = Resolve-WindowsTerminalSettingsPath -Path $SettingsPath -CallerName 'Uninstall-WindowsTerminalScheme'
    if (-not $SettingsPath) { return }

    $schemeName = (Get-BundledThemeBranding -Name $Theme).TerminalScheme['name']

    if ($PSCmdlet.ShouldProcess($SettingsPath, "Remove Windows Terminal color scheme '$schemeName'")) {
        $result = Edit-WindowsTerminalSettings -Path $SettingsPath -RemoveName $schemeName

        if ($result.Action -eq 'NotFound') {
            Write-Warning "Uninstall-WindowsTerminalScheme: no color scheme named '$schemeName' was found in $SettingsPath; nothing removed."
            return
        }
        Write-Host "Removed Windows Terminal color scheme '$schemeName' from $SettingsPath (backup: $SettingsPath.bak)."
        if ($result.StillReferenced) {
            Write-Warning "'$schemeName' is still set as an active colorScheme in settings.json. Pick another color scheme in Windows Terminal so it doesn't fall back to the default."
        }
    }
}
