function Show-PwshProfileChord {
    <#
    .SYNOPSIS
        Lists the keyboard chords this profile wires up, plus the closely related defaults it doesn't
        choose itself.

    .DESCRIPTION
        Renders Get-PwshProfileChordCatalog as a panel: fzf's Ctrl+T/Ctrl+R/Ctrl+G/Ctrl+Spacebar
        chords (Enable-Fzf) and Initialize-PSReadline's Up/Down/Tab/Alt+w/Alt+( bindings, alongside a
        couple of chords that matter for context but aren't this module's own choice — PSFzf's own
        Alt+C, and the PSReadLine defaults some of these chords replace.

        Each row's action/detail/owner/note text is hand-wrapped to the console width with a hanging indent
        that lines up under the chord column, rather than left to the terminal (or
        Format-SpectrePanel's own wrap) to break wherever it likes — which loses the indent and makes
        a wrapped continuation read as an unrelated new line starting at the left margin.

        Two rows reflect the actual configuration rather than always showing: Ctrl+G only appears
        when -FzfGitKeyBindings is passed AND git is actually on PATH (Enable-Fzf's own exact gate —
        it drops the chords on a git-less machine too), and the Ctrl+Spacebar row's displayed chord
        follows -FzfTabChord (its default 'Ctrl+Spacebar' dual-binds Ctrl+@ too, exactly as Enable-Fzf
        does; any other value shows just that literal chord; empty hides the row, since Enable-Fzf
        treats empty as unbound). Called with no arguments, this reflects a fresh default install.

        Initialize-PwshProfile can print this automatically at the end of every startup via
        -ShowChordGuidance (off by default), passing its own -FzfGitKeyBindings/-FzfTabChord through
        so the guidance matches the session's actual configuration; this cmdlet also runs standalone
        any time.

        Each row's chord links to the project that owns it (PSFzf or PSReadLine) where the terminal
        renders Spectre hyperlinks (Windows Terminal, VS Code, and most modern terminals). The chord
        column is the one line per row the wrap logic never touches, so it's the only safe place to
        splice in markup without corrupting the wrap-width math for Action/Owner/Note.

        If PwshSpectreConsole isn't available, the same text is written plainly instead of in a panel.

    .PARAMETER FzfGitKeyBindings
        Whether PSFzf's Ctrl+G git chords are actually bound in this session, same as
        Enable-Fzf/Initialize-PwshProfile's own switch of the same name. Off by default; passing it
        shows the Ctrl+G row only if git is also on PATH, mirroring Enable-Fzf's own gate exactly.

    .PARAMETER FzfTabChord
        The chord PSFzf's fuzzy tab-completion picker is actually bound to, same as
        Enable-Fzf/Initialize-PwshProfile's own -TabExpansionChord. Defaults to 'Ctrl+Spacebar' (shown
        alongside its 'Ctrl+@' dual-bind, exactly as Enable-Fzf sets it up); any other value shows just
        that literal chord. An empty value hides the row, since Enable-Fzf leaves it unbound.

    .EXAMPLE
        Show-PwshProfileChord

        Prints the chords a fresh default install has — no Ctrl+G row, tab-completion on
        Ctrl+Spacebar/Ctrl+@.

    .EXAMPLE
        Show-PwshProfileChord -FzfGitKeyBindings -FzfTabChord 'Ctrl+j'

        Prints what this session's Initialize-PwshProfile call would actually produce with those two
        settings turned on/customized.

    .NOTES
        See also Initialize-PwshProfile's -ShowChordGuidance parameter, which passes its own
        -FzfGitKeyBindings/-FzfTabChord through to this cmdlet.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$FzfGitKeyBindings,

        [Parameter()]
        [string]$FzfTabChord = 'Ctrl+Spacebar'
    )

    # Wraps $Text to $Width without splitting a word, so the caller can hang-indent each continuation
    # line instead of letting the terminal (or Format-SpectrePanel) break it at column 0.
    function Split-PwshProfileChordDetail {
        param(
            [Parameter(Mandatory)]
            [string]$Text,

            [Parameter(Mandatory)]
            [int]$Width
        )
        $lines = @()
        $current = ''
        foreach ($word in ($Text -split '\s+')) {
            $candidate = if ($current) { "$current $word" } else { $word }
            if ($current -and $candidate.Length -gt $Width) {
                $lines += $current
                $current = $word
            }
            else {
                $current = $candidate
            }
        }
        if ($current) { $lines += $current }
        if ($lines.Count -eq 0) { @('') } else { $lines }
    }

    # Drop/adjust the two rows whose activeness or exact key depends on a setting, mirroring
    # Enable-Fzf's own exact gates so this agrees with reality by construction, not by coincidence.
    $rows = @(Get-PwshProfileChordCatalog | Where-Object {
            if ($_.Setting -eq 'FzfGitKeyBindings') {
                $FzfGitKeyBindings -and (Test-CommandAvailable -Name 'git')
            }
            elseif ($_.Setting -eq 'FzfTabChord') {
                -not [string]::IsNullOrWhiteSpace($FzfTabChord)
            }
            else { $true }
        })
    foreach ($row in $rows) {
        if ($row.Setting -eq 'FzfTabChord') {
            $row.Chord = if ($FzfTabChord -in 'Ctrl+Spacebar', 'Ctrl+@') { 'Ctrl+Spacebar / Ctrl+@' } else { $FzfTabChord }
        }
    }

    $chordWidth = ($rows | ForEach-Object { "$($_.Chord)".Length } | Measure-Object -Maximum).Maximum
    $indent = 2 + $chordWidth + 2

    # Decided once, up front: the plain-text fallback below has no markup at all, so link spans must
    # never be baked into $lines when Format-SpectrePanel isn't there to render them.
    $hasSpectre = [bool](Get-Command Format-SpectrePanel -ErrorAction SilentlyContinue)

    # -8 is a margin for the panel's own border and padding (Format-SpectrePanel -Expand fills the
    # console, so its interior is a little narrower than the raw window width).
    $consoleWidth = Get-PwshProfileConsoleWidth
    $wrapWidth = [Math]::Max(30, $consoleWidth - $indent - 8)
    $introWidth = [Math]::Max(30, $consoleWidth - 8)

    $lines = @(
        Split-PwshProfileChordDetail -Text "Keyboard chords this profile wires up, plus the closest related defaults it doesn't choose:" -Width $introWidth
        ''
    )
    foreach ($row in $rows) {
        # Action, Detail, Owner, and Note each start their own line at the hanging-indent column and
        # wrap independently, rather than being joined into one long line for the terminal to break
        # blindly. Detail is the odd one out -- most rows leave it '' and skip straight to Owner; it
        # exists for a row like Ctrl+G, where the per-subkey breakdown doesn't fit in Action's one
        # short sentence and reads better as its own paragraph.
        $blocks = @($row.Action, $row.Detail, $row.Owner, $row.Note) | Where-Object { $_ }
        $atRowStart = $true
        foreach ($block in $blocks) {
            foreach ($wrapped in (Split-PwshProfileChordDetail -Text $block -Width $wrapWidth)) {
                if ($atRowStart) {
                    $chordText = "$($row.Chord)"
                    $chordCell = if ($row.Url -and $hasSpectre) {
                        # Pad the VISIBLE length with plain trailing spaces after the closing tag,
                        # rather than PadRight-ing the markup string itself, which would count the
                        # invisible "[link=...][/]" characters toward the column width.
                        "[link=$($row.Url)]$chordText[/]" + (' ' * ($chordWidth - $chordText.Length))
                    }
                    else {
                        $chordText.PadRight($chordWidth)
                    }
                    $lines += "  $chordCell  $wrapped"
                    $atRowStart = $false
                }
                else {
                    $lines += "  $(' ' * $chordWidth)  $wrapped"
                }
            }
        }
        $lines += ''
    }
    $text = ($lines -join [Environment]::NewLine).TrimEnd()

    if ($hasSpectre) {
        $text | Format-SpectrePanel -Header 'Keyboard chords' -Border Rounded -Color '#c9aaff' -Expand | Out-Host
    }
    else {
        Write-Host $text
    }
}
