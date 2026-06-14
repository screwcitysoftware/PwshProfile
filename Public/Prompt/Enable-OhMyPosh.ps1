function Enable-OhMyPosh {
    <#
    .SYNOPSIS
        Installs (if necessary) and activates the oh-my-posh prompt for the session.

    .DESCRIPTION
        Runs two nested Invoke-Step substeps:
          - Install: if oh-my-posh.exe isn't on PATH, installs it with winget
            (JanDeDobbeleer.OhMyPosh, user scope) and patches the current session's PATH so
            the Initialize substep can see it immediately.
          - Initialize: runs `oh-my-posh init pwsh` (with the resolved theme via `--config`)
            and invokes the emitted script, which installs the prompt function globally.

        By default the module's bundled theme (Assets/Themes/screwcity.omp.json) is used;
        pass -Configuration to override it.

        If the install doesn't produce oh-my-posh.exe on PATH, a warning is emitted (with the
        install result status) and Initialize is skipped (guarded by Get-Command) so profile startup
        continues.

    .PARAMETER Configuration
        Optional path to an oh-my-posh theme file, passed as `--config`. When omitted, the
        module's bundled theme (Assets/Themes/screwcity.omp.json) is used; if that file is
        missing, oh-my-posh falls back to its own default theme.

    .EXAMPLE
        Enable-OhMyPosh -Configuration '~/OneDrive/.config/PoshThemes/craver.modified.omp.json'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Configuration
    )

    Invoke-Step "Install" {
        # Unlike zoxide/fnm (winget portables), oh-my-posh is an installer package: with
        # user scope its bin dir goes on the *user* PATH (registry).
        Install-WingetPackageSafe -Id 'JanDeDobbeleer.OhMyPosh' -Exe 'oh-my-posh.exe' `
            -PathDir (Join-Path $env:LOCALAPPDATA 'Programs\oh-my-posh\bin') `
            -Scope user -CallerName 'Enable-OhMyPosh'
    }

    Invoke-Step "Initialize" {
        if (Get-Command oh-my-posh.exe -ErrorAction SilentlyContinue) {
            if (-not $Configuration) {
                $defaultTheme = Get-BundledThemePath
                if (Test-Path $defaultTheme) { $Configuration = $defaultTheme }
            }
            $configArgs = if ($Configuration) { '--config', $Configuration } else { @() }
            # Run in the global scope (not this module's) so the prompt function and helpers
            # aren't tagged to the module — see Private/Invoke-InGlobalScope.ps1.
            # Suppress stderr (2>$null) so a warning from oh-my-posh can't paint into the live
            # Invoke-Step spinner; only the init script (stdout) is captured and run.
            Invoke-InGlobalScope (oh-my-posh init pwsh @configArgs 2>$null | Out-String)
        }
    }
}
