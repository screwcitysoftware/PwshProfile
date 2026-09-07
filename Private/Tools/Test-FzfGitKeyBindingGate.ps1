function Test-FzfGitKeyBindingGate {
    <#
    .SYNOPSIS
        Whether PSFzf's Ctrl+G git chords are actually active, given the git-key-bindings switch.

    .DESCRIPTION
        The one shared gate behind both Enable-Fzf (which binds the chords) and Show-PwshProfileChord
        (which decides whether to display the Ctrl+G row) — the chords need git itself on PATH, not
        just the switch turned on, so a git-less machine is never left with dead bindings or shown a
        misleading row.

    .PARAMETER GitKeyBindings
        The caller's -GitKeyBindings / -FzfGitKeyBindings switch value.

    .EXAMPLE
        Test-FzfGitKeyBindingGate -GitKeyBindings:$GitKeyBindings
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [bool]$GitKeyBindings
    )

    $GitKeyBindings -and (Test-CommandAvailable -Name 'git')
}
