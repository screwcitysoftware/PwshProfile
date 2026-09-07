function Repair-TerminalIconsCache {
    <#
    .SYNOPSIS
        Removes corrupted Terminal-Icons user theme-cache files so a re-import can regenerate them.

    .DESCRIPTION
        Terminal-Icons persists the user's icon and color themes as CLIXML (`*_icon.xml` / `*_color.xml`).
        It rewrites them with `Export-Clixml -Force` at the END of every import and reads them back with
        `Import-CliXml` at the START of the next one — and those reads are not wrapped in a try/catch.
        When two sessions import the module at the same instant their writes interleave, one file is
        left truncated, and the next import throws an XmlException that fails the whole module load.

        This validates each cache file with a trial Import-Clixml and deletes only the ones that fail to
        parse. Terminal-Icons recreates the deleted built-in themes on the next import, which is the
        "purge corrupt cache, then retry" recovery wired into Import-ModuleSafe's -Repair hook.
        `prefs.xml` is deliberately left alone: Terminal-Icons already guards that read and falls back
        to defaults, so it never throws out of import.

        Failure-tolerant per the module's design rules: a no-op when the storage directory is missing,
        never throws, and idempotent — valid and custom theme files are preserved, so it is safe to call
        on every import attempt.

    .PARAMETER Path
        The theme-storage directory to repair. Defaults to the same location Terminal-Icons' own
        Get-ThemeStoragePath computes, per platform. Exposed mainly so tests can point at a temp
        directory.

    .EXAMPLE
        Import-ModuleSafe Terminal-Icons -Repair { Repair-TerminalIconsCache }

        If the initial import fails, purge the corrupted cache and retry once before warning — how the
        profile's Terminal-Icons startup step invokes it.

    .EXAMPLE
        Repair-TerminalIconsCache

        Manually clean any corrupted theme-cache files in the default storage path.

    .NOTES
        The path resolution mirrors Terminal-Icons.psm1's Get-ThemeStoragePath exactly, so the repaired
        directory is the same one the module reads at import time.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Path
    )

    if (-not $Path) {
        $base = if ($IsLinux -or $IsMacOs) {
            if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { [IO.Path]::Combine($HOME, '.local', 'share') }
        }
        else {
            if ($env:APPDATA) { $env:APPDATA } else { [Environment]::GetFolderPath('ApplicationData') }
        }
        $Path = [IO.Path]::Combine($base, 'powershell', 'Community', 'Terminal-Icons')
    }

    if (-not (Test-Path -LiteralPath $Path)) { return }

    foreach ($file in Get-ChildItem -LiteralPath $Path -File -ErrorAction SilentlyContinue) {
        # Only the unguarded read sites — *_icon.xml / *_color.xml; prefs.xml is guarded inside Terminal-Icons.
        if ($file.Name -notlike '*_icon.xml' -and $file.Name -notlike '*_color.xml') { continue }
        try {
            $null = Import-Clixml -LiteralPath $file.FullName -ErrorAction Stop
        }
        catch {
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
        }
    }
}
