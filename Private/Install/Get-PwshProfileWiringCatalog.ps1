function Get-PwshProfileWiringCatalog {
    <#
    .SYNOPSIS
        Returns the catalog of yes/no wiring choices the install wizard offers — the single source of
        truth for the tree, its legend, and the review summary.

    .DESCRIPTION
        The wizard no longer asks which tools you get; it asks how they wire into your shell. This is
        the one place those toggles are defined, so the checkbox tree, the per-item legend above it,
        and the review panel's summary line cannot disagree about what exists or what it is called.

        Each row carries:
          Group   — the tree section it lands in ('Replacements' or 'Keybindings').
          Label   — the checkbox text. Also the key the Spectre prompt hands back, so labels must be
                    unique across ALL groups, not just within one.
          Setting — the Get-PwshProfileSettingSchema key it drives.
          On/Off  — the value written to that setting when checked / unchecked. Usually $true/$false,
                    but not always: ZoxideCommand is a string, and its checkbox means 'cd' vs 'z'.
                    That is why this is a value pair rather than a boolean flag — it lets a non-boolean
                    setting still be presented as a single honest checkbox.
          Help    — the legend line, in the Format-PwshProfileHelpMarkup convention (**tool**, `code`).

        Rows are rebuilt on every call rather than cached: Read-PwshProfileWiringTree mutates Label to
        render state, so a memoized catalog would leak that between calls.

        Only binary choices belong here. The free-text settings the wizard also collects (bat's theme
        and style, less's options, the fzf tab chord) are prompted separately after the tree, since a
        checkbox cannot express them.

    .EXAMPLE
        Get-PwshProfileWiringCatalog

        Returns every wiring row, in tree order.

    .EXAMPLE
        Get-PwshProfileWiringCatalog | Where-Object Group -eq 'Replacements'

        Just the rows that take over an existing command name.

    .NOTES
        ZoxideCommand's presence here is why Off is 'z' rather than ''. Unchecking the box does not
        disable zoxide (every tool always runs) — it moves zoxide's jump command off `cd` and onto the
        conventional `z`, leaving the built-in cd untouched. A hand-written profile can still pass any
        other name; the wizard just offers the two that matter.
    #>
    [CmdletBinding()]
    param()

    @(
        [pscustomobject]@{
            Group = 'Replacements'; Label = 'cd -> zoxide (smart jump)'
            Setting = 'ZoxideCommand'; On = 'cd'; Off = 'z'
            Help = '`cd` -> **zoxide** — cd learns your most-used directories, so `cd dev` jumps to `C:\Dev` from anywhere. Normal paths keep working. Unchecked, zoxide binds `z` instead and the built-in cd is untouched.'
        }
        [pscustomobject]@{
            Group = 'Replacements'; Label = 'cat -> bat (syntax highlighting)'
            Setting = 'ReplaceCat'; On = $true; Off = $false
            Help = '`cat` -> **bat** — a `cat` with syntax highlighting, line numbers and git marks. Redirection and piping still work; the built-in stays available as `Get-Content`.'
        }
        [pscustomobject]@{
            Group = 'Replacements'; Label = '$env:PAGER -> less'
            Setting = 'SetPager'; On = $true; Off = $false
            Help = '`$env:PAGER` -> **less** — routes PowerShell''s `help`, plus git, delta and gh, through less instead of `more.com`.'
        }
        [pscustomobject]@{
            Group = 'Replacements'; Label = 'more -> less (the command)'
            Setting = 'ReplaceMore'; On = $true; Off = $false
            Help = '`more` -> **less** — aliases the `more` command itself. Separate from the pager above: `help` invokes the literal string `more.com`, so the alias alone would not reach it.'
        }
        [pscustomobject]@{
            Group = 'Replacements'; Label = 'http / https -> xh'
            Setting = 'ReplaceHttp'; On = $true; Off = $false
            Help = '`http` / `https` -> **xh** — a fast HTTPie-style client. These are not built-in commands, so this claims two free names rather than shadowing anything; off by default for exactly that reason.'
        }
        [pscustomobject]@{
            Group = 'Keybindings'; Label = 'Ctrl+G git pickers'
            Setting = 'FzfGitKeyBindings'; On = $true; Off = $false
            Help = '`Ctrl+G` — **PSFzf**''s fzf-powered git pickers, chosen by a second chord: branches, files, hashes, pull requests, stashes, tags. Off by default because **lazygit** already covers git. `Ctrl+T` (files) and `Ctrl+R` (history) are bound either way.'
        }
    )
}
