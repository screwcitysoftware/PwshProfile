function Enable-Less {
    <#
    .SYNOPSIS
        Installs (if necessary) and activates less, a full-featured terminal pager, for the session.

    .DESCRIPTION
        Runs two nested Invoke-Step substeps:
          - Install: if less.exe isn't on PATH, installs it with winget (jftuga.less — GNU less
            compiled standalone for Windows, a portable package) and patches the current session's
            PATH so the Initialize substep can see it immediately.
          - Initialize (guarded by Get-Command less.exe): configures less for the session:
              * Sets $env:LESS to the chosen option string (when -Options is non-empty) so every less
                invocation inherits sane defaults — by default '-R -F -i': raw control chars (color
                passthrough), quit-if-one-screen (short output isn't trapped in the pager), and
                smart-case search.
              * When -ReplaceMore is set, sets $env:PAGER to 'less' and aliases more -> less.exe
                globally. $env:PAGER routes PowerShell's own `help` function (which honors PAGER,
                falling back to more.com), bat, git, delta, and gh through less; the alias shadows
                more.com when the user types `more`.

        less materially upgrades bat: bat's default pager is less, so without less on PATH bat can't
        page colored output (more.com strips ANSI) and just dumps it — installing less gives the
        already-enabled Enable-Bat real color-preserving paging, auto-detected with no extra config.

        If the install doesn't produce less.exe on PATH, a warning is emitted (with winget's captured
        output) and Initialize is skipped (guarded by Get-Command) so profile startup continues.

    .PARAMETER Options
        The option string assigned to $env:LESS for the session, applied to every less invocation.
        Defaults to '-R -F -i' (raw color, quit-if-one-screen, smart-case search). An empty value
        leaves $env:LESS untouched (less keeps its own defaults).

    .PARAMETER ReplaceMore
        When set, sets $env:PAGER to 'less' (so PowerShell's `help`, bat, git, delta, and gh page
        through less instead of more.com) and aliases more -> less.exe in the global scope (with
        -Force, for idempotent reloads), so `more file` renders through less. Off by default, leaving
        $env:PAGER and the more command untouched.

    .EXAMPLE
        Enable-Less

        Installs less if needed and sets $env:LESS to '-R -F -i', leaving more.com as PowerShell's
        help pager. bat auto-detects less and pages with color.

    .EXAMPLE
        Enable-Less -ReplaceMore

        Also sets $env:PAGER to 'less' and aliases more -> less, so `help`, `more`, and color-aware
        CLIs all page through less for the session.

    .NOTES
        Unlike bat and fd, GNU less ships no PowerShell completion generator, so there is no completer
        to register. less also has no fzf/fd-style color palette, so it is not themed to the prompt —
        $env:LESS carries functional defaults only. Verified against PowerShell 7.x: the built-in
        `help` function defaults its pager to more.com but honors $env:PAGER when set to a resolvable
        command, which is what -ReplaceMore relies on (the more -> less alias alone does not redirect
        `help`, since `help` invokes the literal string more.com).
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Options = '-R -F -i',

        [Parameter()]
        [switch]$ReplaceMore
    )

    Invoke-Step "Install" {
        # less is a winget portable: its exe lands in the default Links dir.
        Install-WingetPackageSafe -Id 'jftuga.less' -Exe 'less.exe' -CallerName 'Enable-Less'
    }

    Invoke-Step "Initialize" {
        if (Get-Command less.exe -ErrorAction SilentlyContinue) {
            # Drive less's defaults through environment variables (process-global already, so these
            # are plain assignments — no Invoke-InGlobalScope needed for env vars).
            if (-not [string]::IsNullOrWhiteSpace($Options)) { $env:LESS = $Options }

            if ($ReplaceMore) {
                # $env:PAGER routes pwsh `help`, bat, git, delta, gh through less; the alias shadows
                # more.com when the user types `more` (-Force for idempotent reloads).
                $env:PAGER = 'less'
                Set-Alias -Name more -Value less.exe -Scope Global -Force
            }
        }
    }
}
