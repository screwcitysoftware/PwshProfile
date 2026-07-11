function Install-WindowsTerminalScheme {
    <#
    .SYNOPSIS
        Adds a bundled theme's matching color scheme to Windows Terminal's settings.json.

    .DESCRIPTION
        Writes the Windows Terminal color scheme that matches a bundled prompt theme into the user's
        settings.json `schemes` array, so the terminal's own 16-color ANSI palette, background, and
        cursor match the oh-my-posh prompt. The scheme colors come from the same source of truth as
        the bat/fd/fzf colors — Get-BundledThemeBranding — and the scheme is named after the theme's
        display name ('Screw City' / 'Forest City'), so it shows up under that name in Windows
        Terminal's Settings -> Color schemes list.

        By default the scheme is only registered (you then pick it per-profile in Windows Terminal, or
        pass -SetDefault to also set it as profiles.defaults.colorScheme so it applies immediately).

        The edit is idempotent: re-running replaces the same-named scheme rather than duplicating it.
        The original settings.json is backed up to '<settings.json>.bak' before the rewrite. Supports
        -WhatIf / -Confirm.

        If Windows Terminal's settings.json can't be found (Windows Terminal not installed, or never
        launched), a warning is emitted and nothing is changed. Pass -SettingsPath to point at a
        specific file.

        JSONC note: settings.json may contain // comments; the parse -> rewrite round-trip does not
        preserve comments or hand-formatting (the .bak backup is the safety net).

    .PARAMETER Theme
        The bundled theme whose matching scheme to install (tab-completes): the default 'screwcity',
        or any bundled theme (run Get-BundledThemeName for the full set). Custom/unknown themes fall
        back to the Screw City scheme.

    .PARAMETER SettingsPath
        Optional path to the Windows Terminal settings.json to edit. Defaults to the first existing
        of the stable, preview, and unpackaged install locations (Get-WindowsTerminalSettingsPath).

    .PARAMETER SetDefault
        Also set the scheme as profiles.defaults.colorScheme so it applies to all profiles
        immediately, instead of only registering it for you to select.

    .EXAMPLE
        Install-WindowsTerminalScheme

        Adds the 'Screw City' color scheme to settings.json for you to select in Windows Terminal.

    .EXAMPLE
        Install-WindowsTerminalScheme -Theme forestcity -SetDefault

        Adds the 'Forest City' scheme and makes it the default color scheme for all profiles.

    .EXAMPLE
        Install-WindowsTerminalScheme -WhatIf

        Shows what would change without writing.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interactive confirmation for a user-invoked install command — same intent as Show-NerdFontSetup (which the rule exempts only by its Show- verb). The result is host feedback, not pipeline data.')]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0)]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $base = (Get-Module ScrewCitySoftware.PwshProfile).ModuleBase
                if ($base) {
                    Get-ChildItem -Path (Join-Path $base 'Assets' 'Themes') -Filter *.omp.json -ErrorAction SilentlyContinue |
                        ForEach-Object { $_.Name -replace '\.omp\.json$', '' } |
                        Where-Object { $_ -like "$wordToComplete*" } |
                        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
                }
            })]
        [ValidateScript({ $_ -in (Get-BundledThemeName) },
            ErrorMessage = "'{0}' is not a bundled theme. Check Assets/Themes for the available themes.")]
        [string]$Theme = 'screwcity',

        [Parameter()]
        [string]$SettingsPath,

        [Parameter()]
        [switch]$SetDefault
    )

    if (-not $SettingsPath) {
        $SettingsPath = Get-WindowsTerminalSettingsPath
    }
    if (-not $SettingsPath -or -not (Test-Path -LiteralPath $SettingsPath -PathType Leaf)) {
        Write-Warning "Install-WindowsTerminalScheme: Windows Terminal settings.json not found. Is Windows Terminal installed and launched at least once? Pass -SettingsPath to override."
        return
    }

    $scheme = (Get-BundledThemeBranding -Name $Theme).TerminalScheme
    $schemeName = $scheme['name']

    if ($PSCmdlet.ShouldProcess($SettingsPath, "Install Windows Terminal color scheme '$schemeName'")) {
        $editParams = @{ Path = $SettingsPath; Scheme = $scheme }
        if ($SetDefault) { $editParams['SetDefault'] = $true }
        $result = Edit-WindowsTerminalSettings @editParams

        $verb = if ($result.Action -eq 'Replaced') { 'Updated' } else { 'Added' }
        $message = "$verb Windows Terminal color scheme '$schemeName' in $SettingsPath (backup: $SettingsPath.bak)."
        if ($SetDefault) {
            $message += " Set it as the default color scheme."
        }
        else {
            $message += " Select it in Windows Terminal: Settings -> your profile -> Appearance -> Color scheme."
        }
        Write-Host $message
    }
}
