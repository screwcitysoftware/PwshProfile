function Repair-TerminalIconsCache {
    <#
    .SYNOPSIS
        Removes corrupted Terminal-Icons user theme-cache files so a re-import can regenerate them.

    .DESCRIPTION
        Terminal-Icons persists the user's icon and color themes as CLIXML under
        `…\powershell\Community\Terminal-Icons\` (`*_icon.xml` / `*_color.xml`). It rewrites those
        files via `Export-Clixml -Force` at the END of every import and reads them back with
        `Import-CliXml` at the START of the NEXT import — and those reads are NOT wrapped in a
        try/catch. When two PowerShell sessions import the module at the same instant their writes
        interleave and one file is left truncated; the next import then throws an
        `System.Xml.XmlException` (e.g. "The 'DCT' start tag … does not match the end tag of 'En'")
        and the whole module fails to load.

        This validates each `*_icon.xml` / `*_color.xml` in the theme-storage directory with a trial
        `Import-Clixml` and deletes only the ones that fail to parse. Terminal-Icons recreates the
        deleted built-in themes (and re-exports fresh copies) on the next import, so a follow-up
        import succeeds — that is the intended "purge corrupt cache, then retry" recovery wired into
        `Import-ModuleSafe`'s `-Repair` hook from the Terminal-Icons startup step. `prefs.xml` is
        intentionally left alone: Terminal-Icons already guards that read and falls back to defaults
        on a parse error, so it never throws out of import.

        Guarded and failure-tolerant per the module's design rules: it is a no-op when the storage
        directory does not exist, never throws, and is idempotent — valid (including custom) theme
        files are preserved, so it is safe to call on every import attempt.

    .PARAMETER Path
        The Terminal-Icons theme-storage directory to repair. Defaults to the same location
        Terminal-Icons' own `Get-ThemeStoragePath` computes: `$env:APPDATA\powershell\Community\Terminal-Icons`
        on Windows, or `$XDG_CONFIG_HOME` (falling back to `~/.local/share`) `…/powershell/Community/Terminal-Icons`
        on Linux/macOS. Exposed mainly so tests can point it at a temp directory.

    .EXAMPLE
        Import-ModuleSafe Terminal-Icons -Repair { Repair-TerminalIconsCache }

        If the initial Terminal-Icons import fails, purge the corrupted theme cache and retry once
        before warning — how the profile's Terminal-Icons startup step invokes it.

    .EXAMPLE
        Repair-TerminalIconsCache

        Manually clean any corrupted Terminal-Icons theme-cache files in the default storage path.

    .NOTES
        The path-resolution mirrors Terminal-Icons.psm1's Get-ThemeStoragePath exactly so the
        repaired directory is the same one the module reads at import time.
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
