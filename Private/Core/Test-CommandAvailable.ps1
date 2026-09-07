function Test-CommandAvailable {
    <#
    .SYNOPSIS
        Reports whether a command is resolvable, without paying Get-Command's cost when it isn't.

    .DESCRIPTION
        The cheap presence check behind every "skip this tool if it isn't installed" guard.

        Get-Command is fast when a command exists and very slow when it doesn't: measured at 0.4ms for
        a hit and ~130ms for a miss, because a miss walks all of PATH against every PATHEXT entry
        before giving up. Startup guards for tools the user may not have — az, docker, tailscale, op,
        gh, plus any Enable-* whose tool failed to install — sit squarely on that cliff, so a machine
        missing six CLIs pays roughly 780ms per shell start to learn nothing.

        This checks the cases that actually occur, cheapest first: a function or alias shadowing the
        name (both free, and the only things that beat PATH in real resolution), then PATH for
        .exe/.cmd/.bat. Measured at ~8ms on a miss, versus ~130ms.

        It is deliberately narrower than Get-Command, which also resolves cmdlets, .ps1, .com and the
        rest of PATHEXT. A CLI shipped as a .ps1 shim would not be found here. That is the failure
        direction to keep in mind: a false negative silently no-ops a feature rather than erroring, so
        Tests/Test-CommandAvailable.Tests.ps1 asserts agreement with Get-Command for every tool this
        module actually probes.

    .PARAMETER Name
        The command to look for. An explicit extension ('fzf.exe') is honored as given; a bare name
        ('docker') is tried against .exe, .cmd and .bat.

    .EXAMPLE
        if (Test-CommandAvailable -Name 'fzf.exe') { ... }

        The standard Enable-* Initialize guard: configure the tool only when it is actually present.

    .NOTES
        Install-WingetPackageSafe's POST-install re-check deliberately still uses Get-Command. That
        one is the documented success signal for an install, where ground truth matters more than the
        milliseconds, and it only runs after an install actually ran.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    if (Test-Path -LiteralPath "Function:\$Name") { return $true }
    if (Test-Path -LiteralPath "Alias:\$Name") { return $true }

    $extensions = if ([System.IO.Path]::GetExtension($Name)) { @('') } else { '.exe', '.cmd', '.bat' }
    foreach ($dir in ($env:PATH -split [System.IO.Path]::PathSeparator)) {
        if (-not $dir) { continue }
        foreach ($extension in $extensions) {
            if ([System.IO.File]::Exists((Join-Path $dir ($Name + $extension)))) { return $true }
        }
    }
    $false
}
