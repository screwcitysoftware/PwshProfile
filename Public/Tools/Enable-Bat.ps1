function Enable-Bat {
    <#
    .SYNOPSIS
        Installs (if necessary) and activates bat, a cat clone with syntax highlighting, for the
        session.

    .DESCRIPTION
        Runs two nested Invoke-Step substeps:
          - Install: if bat.exe isn't on PATH, installs it with winget (sharkdp.bat, a portable
            package) and patches the current session's PATH so the Initialize substep can see it
            immediately.
          - Initialize (guarded by Get-Command bat.exe): configures bat's appearance and tab
            completion for the session:
              * Sets $env:BAT_THEME to the chosen syntax theme (when -Theme is non-empty) so bat's
                colors blend with the active oh-my-posh theme, and $env:BAT_STYLE to the chosen
                layout components.
              * When -ReplaceCat is set, aliases cat -> bat.exe globally (with -Force, since the
                built-in cat alias for Get-Content is ReadOnly), so `cat file` renders through bat.
              * Registers bat's PowerShell tab completion. bat emits a Register-ArgumentCompleter
                script via `bat --completion ps1`; it is run through Invoke-InGlobalScope (not a bare
                Invoke-Expression) so the registered completer lands in the true global scope and
                isn't tagged to this module — see Private/Core/Invoke-InGlobalScope.ps1.

        If the install doesn't produce bat.exe on PATH, a warning is emitted (with winget's captured
        output) and Initialize is skipped (guarded by Get-Command) so profile startup continues.

    .PARAMETER Theme
        The bat syntax-highlighting theme, assigned to $env:BAT_THEME for the session (a value from
        `bat --list-themes`, e.g. 'Dracula' or 'gruvbox-dark'). Initialize-PwshProfile resolves this
        from the active theme's branding so bat's colors match the prompt. An empty value leaves
        $env:BAT_THEME untouched (bat keeps its own default).

    .PARAMETER Style
        The bat layout, assigned to $env:BAT_STYLE — a comma-separated list of components (e.g.
        'numbers,changes,header', 'full', 'plain'). Defaults to 'numbers,changes,header': line
        numbers, git change marks, and a file header, without the heavier grid.

    .PARAMETER ReplaceCat
        When set, aliases cat -> bat.exe in the global scope, so the built-in cat (an alias for
        Get-Content) is replaced by bat for the session. Off by default, leaving cat untouched.

    .EXAMPLE
        Enable-Bat -Theme Dracula

        Installs bat if needed and sets its theme to Dracula with the default style, leaving cat alone.

    .EXAMPLE
        Enable-Bat -Theme gruvbox-dark -ReplaceCat

        Sets the gruvbox-dark theme and replaces the cat alias with bat for the session.

    .NOTES
        Unlike jq, bat ships a PowerShell completer: `bat --completion ps1` emits a
        Register-ArgumentCompleter script, registered here in the Initialize substep (run in the
        global scope so it isn't attributed to the module). bat's themes blend with the bundled
        oh-my-posh themes when driven through Initialize-PwshProfile (screwcity -> Dracula,
        forestcity -> gruvbox-dark).
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Theme = '',

        [Parameter()]
        [string]$Style = 'numbers,changes,header',

        [Parameter()]
        [switch]$ReplaceCat
    )

    Invoke-Step "Install" {
        # bat is a winget portable: its exe lands in the Links dir.
        Install-WingetPackageSafe -Id 'sharkdp.bat' -Exe 'bat.exe' `
            -PathDir (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links') `
            -CallerName 'Enable-Bat'
    }

    Invoke-Step "Initialize" {
        if (Get-Command bat.exe -ErrorAction SilentlyContinue) {
            # Drive bat's appearance through environment variables (process-global already, so these
            # are plain assignments — no Invoke-InGlobalScope needed for env vars).
            if (-not [string]::IsNullOrWhiteSpace($Theme)) { $env:BAT_THEME = $Theme }
            if (-not [string]::IsNullOrWhiteSpace($Style)) { $env:BAT_STYLE = $Style }

            if ($ReplaceCat) {
                # The built-in cat alias (Get-Content) is ReadOnly, so -Force is required to retarget it.
                Set-Alias -Name cat -Value bat.exe -Scope Global -Force
            }

            # Register bat's completer in the global scope (not this module's) so it isn't tagged to
            # the module — see Private/Core/Invoke-InGlobalScope.ps1.
            Invoke-InGlobalScope ((bat --completion ps1) | Out-String)
        }
    }
}
