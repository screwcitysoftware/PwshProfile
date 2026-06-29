function Get-WindowsTerminalSettingsPath {
    <#
    .SYNOPSIS
        Returns the path to the user's Windows Terminal settings.json, or $null if none is found.

    .DESCRIPTION
        Single source of truth for locating Windows Terminal's settings.json. Windows Terminal
        ships in a few flavors that each store settings.json in a different place; this probes the
        known locations in order and returns the first that exists:

          1. Stable (Store / packaged):  %LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
          2. Preview (packaged):         %LOCALAPPDATA%\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json
          3. Unpackaged (scoop / portable): %LOCALAPPDATA%\Microsoft\Windows Terminal\settings.json

        Returns $null when none exist (e.g. Windows Terminal isn't installed, or has never been
        launched so settings.json hasn't been generated yet) — callers treat that as a silent,
        non-fatal condition (Write-Warning + return), not an error.

    .EXAMPLE
        $path = Get-WindowsTerminalSettingsPath
        if ($path) { Install-WindowsTerminalScheme -SettingsPath $path }
    #>
    [CmdletBinding()]
    param()

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json')
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json')
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }

    return $null
}
