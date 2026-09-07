function Resolve-WindowsTerminalSettingsPath {
    <#
    .SYNOPSIS
        Resolves the Windows Terminal settings.json to edit, warning and returning $null when there
        isn't one.

    .DESCRIPTION
        The shared preamble for the public Windows Terminal commands (Install-WindowsTerminalScheme,
        Uninstall-WindowsTerminalScheme, Set-WindowsTerminalFont). An explicit -Path is honored as
        given; otherwise the path is discovered via Get-WindowsTerminalSettingsPath.

        Either way the result must be an existing file. When it isn't — Windows Terminal isn't
        installed, or has never been launched, so settings.json doesn't exist yet — this warns and
        returns $null so the caller can return without changing anything, per the module's
        failure-tolerance rule.

    .PARAMETER Path
        An explicit settings.json path from the caller's -SettingsPath. Empty or $null triggers
        discovery instead.

    .PARAMETER CallerName
        The calling function's name, used to prefix the warning so the source is identifiable.

    .EXAMPLE
        $SettingsPath = Resolve-WindowsTerminalSettingsPath -Path $SettingsPath -CallerName 'Set-WindowsTerminalFont'
        if (-not $SettingsPath) { return }

        The standard two-line preamble each Windows Terminal command opens with.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$CallerName
    )

    if (-not $Path) {
        $Path = Get-WindowsTerminalSettingsPath
    }
    if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Warning "${CallerName}: Windows Terminal settings.json not found. Is Windows Terminal installed and launched at least once? Pass -SettingsPath to override."
        return
    }
    $Path
}
