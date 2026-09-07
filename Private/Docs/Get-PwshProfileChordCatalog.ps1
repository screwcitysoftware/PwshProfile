function Get-PwshProfileChordCatalog {
    <#
    .SYNOPSIS
        Returns every keyboard chord this profile configures, plus the closely related defaults that
        aren't this module's own choice — the single source of truth Show-PwshProfileChord renders.

    .DESCRIPTION
        A documentation snapshot of the profile's wiring — not a live read of the current session's
        actual PSReadLine handler table, but Show-PwshProfileChord does filter/adjust the two rows
        whose activeness or exact key genuinely depends on a setting (see Setting below), using the
        same values Initialize-PwshProfile passes to Enable-Fzf. The other seven rows are unconditional
        and always shown.

        Each row carries:
          Chord   — the key combination, as a user would read it.
          Action  — what it does, present tense.
          Detail  — an optional second paragraph, its own line below Action, for a row whose
                    explanation doesn't fit one short sentence (Ctrl+G's per-subkey breakdown). ''
                    for every row that doesn't need one — most don't.
          Owner   — the function/module responsible, and whether it's on by default, opt-in, or
                    configurable.
          Note    — extra context, most usefully "this isn't this module's choice" (PSFzf's own Alt+C)
                    or "this replaces a PSReadLine/PSFzf default" (Ctrl+R, Up/Down). '' when there's
                    nothing more to say.
          Url     — the project that owns the chord (PSFzf for the fzf-picker rows, PSReadLine for
                    Initialize-PSReadline's own rows), so Show-PwshProfileChord can link the chord to
                    it. PSFzf, not the `fzf` binary itself (already linked from the tool catalog),
                    since these rows are all PSFzf's PSReadLine integration, not fzf.
          Setting — $null for the seven unconditional rows; otherwise the Initialize-PwshProfile
                    parameter that governs this one: 'FzfGitKeyBindings' (Ctrl+G is hidden unless that
                    switch is on AND git is actually on PATH — Enable-Fzf's own exact gate) or
                    'FzfTabChord' (the Chord text is rewritten to the real configured key; empty hides
                    the row, since Enable-Fzf treats empty as unbound). Pure metadata Show-PwshProfileChord
                    reads to decide what to do with a row — the same role the tool/module catalogs'
                    Tool column already plays.

    .EXAMPLE
        Get-PwshProfileChordCatalog

        Every chord this profile touches, in the order Show-PwshProfileChord displays them.

    .NOTES
        Rows are rebuilt on every call rather than cached, matching the other catalogs in this module.
    #>
    [CmdletBinding()]
    param()

    # Every row declares all seven properties, even where Detail/Note/Setting is '' or $null: the
    # suite runs under Set-StrictMode -Version Latest, where reading an omitted property would throw.
    $psfzf = 'https://github.com/kelleyma49/PSFzf'
    $psreadline = 'https://github.com/PowerShell/PSReadLine'
    @(
        [pscustomobject]@{
            Chord   = 'Ctrl+T'
            Action  = 'Fuzzy-pick a file or directory and drop its path at the cursor (bat preview)'
            Detail  = ''
            Owner   = 'Enable-Fzf -ProviderChord (always bound)'
            Note    = ''
            Url     = $psfzf
            Setting = $null
        }
        [pscustomobject]@{
            Chord   = 'Ctrl+R'
            Action  = 'Fuzzy-search command history'
            Detail  = ''
            Owner   = 'Enable-Fzf -HistoryChord (always bound)'
            Note    = "Overrides PSReadLine's native reverse-history search on this chord; Ctrl+S " +
            '(ForwardSearchHistory) is the untouched pairing.'
            Url     = $psfzf
            Setting = $null
        }
        [pscustomobject]@{
            Chord   = 'Ctrl+G, Ctrl+<subkey>'
            Action  = 'Fuzzy git pickers, chosen by a second chord:'
            Detail  = 'B branches, F files, H hashes, P pull requests, S stashes, T tags'
            Owner   = 'Enable-Fzf -GitKeyBindings (opt-in, off by default)'
            Note    = 'Off by default because lazygit already covers git.'
            Url     = $psfzf
            Setting = 'FzfGitKeyBindings'
        }
        [pscustomobject]@{
            Chord   = 'Ctrl+Spacebar / Ctrl+@'
            Action  = "Fuzzy completion — opens an fzf picker over what Tab would complete"
            Detail  = ''
            Owner   = "Enable-Fzf -TabExpansionChord (configurable, default 'Ctrl+Spacebar')"
            Note    = "Tab itself stays the classic MenuComplete menu; many terminals send the same " +
            'byte for both chords.'
            Url     = $psfzf
            Setting = 'FzfTabChord'
        }
        [pscustomobject]@{
            Chord   = 'Alt+C'
            Action  = 'Fuzzy-pick a directory and cd into it'
            Detail  = ''
            Owner   = "PSFzf itself — bound automatically on import, not this module's choice"
            Note    = "Enable-Fd's -IntegrateFzf is what makes it return real results " +
            '(sets $env:FZF_ALT_C_COMMAND).'
            Url     = $psfzf
            Setting = $null
        }
        [pscustomobject]@{
            Chord   = 'UpArrow / DownArrow'
            Action  = 'Prefix-aware history search'
            Detail  = ''
            Owner   = 'Initialize-PSReadline (always applied)'
            Note    = "Replaces PSReadLine's plain PreviousHistory/NextHistory (linear recall)."
            Url     = $psreadline
            Setting = $null
        }
        [pscustomobject]@{
            Chord   = 'Tab'
            Action  = 'Menu-style completion (MenuComplete)'
            Detail  = ''
            Owner   = 'Initialize-PSReadline (always applied)'
            Note    = ''
            Url     = $psreadline
            Setting = $null
        }
        [pscustomobject]@{
            Chord   = 'Alt+w'
            Action  = "Park the half-typed line into history without running it, then clear the line"
            Detail  = ''
            Owner   = 'Initialize-PSReadline (always applied)'
            Note    = ''
            Url     = $psreadline
            Setting = $null
        }
        [pscustomobject]@{
            Chord   = 'Alt+('
            Action  = 'Wrap the current selection (or the whole line) in parentheses'
            Detail  = ''
            Owner   = 'Initialize-PSReadline (always applied)'
            Note    = ''
            Url     = $psreadline
            Setting = $null
        }
    )
}
