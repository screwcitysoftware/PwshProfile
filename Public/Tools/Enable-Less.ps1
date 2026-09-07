function Enable-Less {
    <#
    .SYNOPSIS
        Installs (if necessary) and activates less, a full-featured terminal pager.

    .DESCRIPTION
        Runs two nested Invoke-Step substeps:
          - Install: if less.exe isn't on PATH, installs jftuga.less (GNU less built standalone for
            Windows) with winget and patches the current session's PATH.
          - Initialize (guarded by Test-CommandAvailable): sets $env:LESS from -Options, and applies
            the two independent overrides -SetPager ($env:PAGER) and -ReplaceMore (the more alias).

        less materially upgrades bat: bat's default pager is less, so without it bat can't page colored
        output (more.com strips ANSI) and just dumps it. Installing less gives an already-enabled bat
        real color-preserving paging, auto-detected with no extra config.

        If the install doesn't produce less.exe on PATH, a warning is emitted and Initialize is skipped
        so profile startup continues.

    .PARAMETER Options
        The option string assigned to $env:LESS, applied to every less invocation. Defaults to
        '-R -F -i': raw color passthrough, quit-if-one-screen, and smart-case search. Empty leaves
        less's own defaults in place.

    .PARAMETER SetPager
        Set $env:PAGER to 'less', routing PowerShell's `help`, bat, git, delta and gh through it. Off
        by default, leaving $env:PAGER untouched.

    .PARAMETER ReplaceMore
        Alias more -> less globally, so typing `more` gets less. Off by default. Independent of
        -SetPager: this shadows the `more` command, that redirects programs which consult $env:PAGER.

    .EXAMPLE
        Enable-Less

        Installs less if needed and sets $env:LESS, leaving $env:PAGER and more.com alone. bat
        auto-detects less and pages with color regardless.

    .EXAMPLE
        Enable-Less -SetPager -ReplaceMore

        Also makes less the default pager, so `help`, `more`, and color-aware CLIs all page through it.

    .EXAMPLE
        Enable-Less -SetPager

        Routes `help` and the color CLIs through less while leaving `more` as more.com.

    .NOTES
        Unlike bat and fd, GNU less ships no PowerShell completion generator, so there is no completer
        to register, and it has no fzf/fd-style palette, so it is not themed — $env:LESS carries
        functional defaults only. Verified on PowerShell 7.x: the built-in `help` defaults to more.com
        but honors $env:PAGER, which is what -SetPager relies on. The more -> less alias alone does
        not redirect `help`, since `help` invokes the literal string more.com — which is exactly why
        these two are separate switches rather than one.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Options = '-R -F -i',

        [Parameter()]
        [switch]$SetPager,

        [Parameter()]
        [switch]$ReplaceMore
    )

    Invoke-Step "Install" {
        # less is a winget portable: its exe lands in the default Links dir.
        Install-WingetPackageSafe -Id 'jftuga.less' -Exe 'less.exe' -CallerName 'Enable-Less'
    }

    Invoke-Step "Initialize" {
        if (Test-CommandAvailable -Name 'less.exe') {
            # Env vars are process-global, so plain assignments — no Invoke-InGlobalScope needed.
            if (-not [string]::IsNullOrWhiteSpace($Options)) { $env:LESS = $Options }

            # Two independent overrides. $env:PAGER routes pwsh `help`, bat, git, delta and gh through
            # less; the alias shadows more.com only when the user literally types `more` (-Force for
            # idempotent reloads). Neither implies the other — `help` invokes the literal string
            # more.com, so the alias alone does not redirect it.
            if ($SetPager) { $env:PAGER = 'less' }
            if ($ReplaceMore) { Set-Alias -Name more -Value less.exe -Scope Global -Force }
        }
    }
}
