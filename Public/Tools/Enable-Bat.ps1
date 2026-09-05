function Enable-Bat {
    <#
    .SYNOPSIS
        Installs (if necessary) and activates bat, a cat clone with syntax highlighting.

    .DESCRIPTION
        Runs two nested Invoke-Step substeps:
          - Install: if bat.exe isn't on PATH, installs sharkdp.bat with winget and patches the current
            session's PATH so the Initialize substep can see it immediately.
          - Initialize (guarded by Get-Command bat.exe): sets $env:BAT_THEME and $env:BAT_STYLE,
            optionally aliases cat -> bat, and registers bat's own completer from `bat --completion ps1`
            through Invoke-InGlobalScope.

        Under -ReplaceCat the completer's -CommandName is extended to cover the `cat` alias too, since
        PowerShell completers don't follow aliases — the same trick Enable-Xh uses for http/https.

        If the install doesn't produce bat.exe on PATH, a warning is emitted and Initialize is skipped
        so profile startup continues.

    .PARAMETER Theme
        bat's syntax-highlighting theme (a value from `bat --list-themes`), assigned to $env:BAT_THEME.
        Initialize-PwshProfile resolves this from the active theme's branding. Empty leaves bat's own
        default in place.

    .PARAMETER Style
        bat's layout, assigned to $env:BAT_STYLE — a comma-separated component list. Defaults to
        'numbers,changes,header': line numbers, git change marks and a file header, without the grid.

    .PARAMETER ReplaceCat
        Alias cat -> bat globally, replacing the built-in cat (an alias for Get-Content), and extend
        bat's completer to that alias. Off by default, leaving cat and its completion untouched.

    .EXAMPLE
        Enable-Bat -Theme Dracula

        Installs bat if needed and sets its theme to Dracula with the default style, leaving cat alone.

    .EXAMPLE
        Enable-Bat -Theme gruvbox-dark -ReplaceCat

        Sets the gruvbox-dark theme and replaces the cat alias with bat for the session.

    .NOTES
        bat's completer registers under -CommandName 'bat' (with -Native and single quotes, unlike xh).
        The -ReplaceCat extension is a string -replace coupled to that exact literal, so a future bat
        build that re-quotes it would silently drop only the alias's completion — bat itself would still
        complete. bat's themes blend with the bundled oh-my-posh themes through Initialize-PwshProfile
        (screwcity -> Dracula, forestcity -> gruvbox-dark).
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Theme,

        [Parameter()]
        [string]$Style = 'numbers,changes,header',

        [Parameter()]
        [switch]$ReplaceCat
    )

    Invoke-Step "Install" {
        # bat is a winget portable: its exe lands in the default Links dir.
        Install-WingetPackageSafe -Id 'sharkdp.bat' -Exe 'bat.exe' -CallerName 'Enable-Bat'
    }

    Invoke-Step "Initialize" {
        if (Get-Command bat.exe -ErrorAction SilentlyContinue) {
            # Env vars are process-global, so plain assignments — no Invoke-InGlobalScope needed.
            if (-not [string]::IsNullOrWhiteSpace($Theme)) { $env:BAT_THEME = $Theme }
            if (-not [string]::IsNullOrWhiteSpace($Style)) { $env:BAT_STYLE = $Style }

            if ($ReplaceCat) {
                # The built-in cat alias (Get-Content) is ReadOnly, so -Force is required to retarget it.
                Set-Alias -Name cat -Value bat.exe -Scope Global -Force
            }

            # Global scope so bat's completer isn't tagged to this module.
            $batCompletion = bat --completion ps1
            if ($ReplaceCat) {
                # Extend bat's completer to cover the `cat` alias too — PowerShell completers don't
                # follow aliases. Coupled to bat's exact `-CommandName 'bat'` output: a change to that
                # quoting silently no-ops and `cat` loses completion (bat itself still works). Gated on
                # -ReplaceCat, since without the alias `cat` is still Get-Content.
                $batCompletion = $batCompletion -replace "-CommandName 'bat'", "-CommandName 'bat', 'cat'"
            }
            Invoke-InGlobalScope ($batCompletion | Out-String)
        }
    }
}
