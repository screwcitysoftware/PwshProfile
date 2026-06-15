function Install-PwshProfile {
    <#
    .SYNOPSIS
        Interactive wizard that wires ScrewCitySoftware.PwshProfile into a PowerShell profile file.

    .DESCRIPTION
        Walks you through a PwshSpectreConsole wizard and writes a marker-wrapped bootstrap block — a
        tools snapshot comment plus a tailored Initialize-PwshProfile call (which auto-loads the module
        when it runs, so no import line is needed) — into a profile file (by default $PROFILE). It is the
        one-time setup companion to Initialize-PwshProfile, which then runs every session from that block.

        On a re-run it parses the existing block to default each prompt to your previous choices and to
        flag tools added to the module since (shown "(new)" and starting unchecked).

        Note: this wires the module into your profile *file*; it does not install the module itself
        from the gallery (use Install-PSResource ScrewCitySoftware.PwshProfile for that).

        The wizard walks one forward pass — an optional Nerd Font install, a set of winget client
        settings, theme, an optional banner (a yes/no that gates the text/color/alignment/font
        prompts), the step icon, and a Features step (pick specific tools from an opt-in tree, or enable
        everything including future additions; oh-my-posh is always on) — then lands on a review screen
        where any step can be re-edited before submitting, or the whole setup cancelled without writing. The Nerd
        Font install uses the NerdFonts module (CurrentUser scope, no admin required), defaulting to
        the recommended Meslo + CascadiaCode pairing. The winget settings (default install scope,
        progress-bar style, anonymize-displayed-paths, suppress-install-notes) are pre-filled from
        the current settings.json and merged back into it via Set-WingetSetting at the end of the
        run — a one-time machine action, not part of the bootstrap block (so re-running the wizard
        re-applies them; -WhatIf previews without touching settings.json).

        Your existing profile code is never destroyed:
          - A new file (and its parent directory) is created if needed.
          - An existing managed block is replaced in place, so the command is safe to re-run to
            change options.
          - Any other existing content is left intact, with the block prepended above it.
          - A profile that already contains a bare 'Import-Module ScrewCitySoftware.PwshProfile'
            (no markers) is left untouched unless -Force is given.

        This is a user-invoked setup command (not silent startup), so genuine errors throw. It is
        interactive-only: when the Spectre prompt cmdlets are unavailable it warns that an interactive
        session is required and makes no changes (rather than guessing at a configuration).

    .PARAMETER Path
        The profile file to configure. Defaults to $PROFILE (current user, current host). Pass an
        explicit path to target another profile (e.g. the all-hosts profile or the VS Code host
        profile).

    .PARAMETER Force
        When the target already contains a bare module import but no managed markers, prepend the
        managed block anyway instead of treating the file as already wired.

    .PARAMETER PassThru
        Emit a result object ([pscustomobject] with Path, Action, and Changed). By default the
        command writes the file and returns nothing.

    .EXAMPLE
        Install-PwshProfile

        Runs the wizard and writes the bootstrap into $PROFILE, creating it (and its directory) if
        needed.

    .EXAMPLE
        Install-PwshProfile -WhatIf

        Walks the wizard and previews the write without changing any file.

    .EXAMPLE
        Install-PwshProfile -Path $PROFILE.CurrentUserAllHosts

        Configures the current user's all-hosts profile instead of the current-host one.

    .EXAMPLE
        Install-PwshProfile -Path ~/Documents/PowerShell/Microsoft.VSCode_profile.ps1

        Configures the VS Code integrated-terminal host profile.

    .NOTES
        $PROFILE is host-specific — the VS Code and ISE hosts use different files than the default
        console. The file is written as UTF-8 without a BOM. Re-run any time to change settings; the
        managed block is rewritten in place. Spectre prompts only render in an interactive console.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '',
        Justification = 'SupportsShouldProcess is declared so -WhatIf/-Confirm are accepted and flow via $WhatIfPreference into the gated writer Write-PwshProfileBlock (and the -not $WhatIfPreference guards on the font/winget steps); this function intentionally delegates rather than calling ShouldProcess itself. Covered by the -WhatIf tests.')]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Path = $PROFILE,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$PassThru
    )

    # The wizard's chrome uses fixed colors decoupled from the prompt theme being configured: the
    # module's signature purple as the accent, soft cyan for code literals / paths.
    $accent = '#c9aaff'
    $code = '#5fd7ff'
    $marker = Get-PwshProfileMarker

    # Detect an existing managed block so the intro can say "updating" and to drive the wizard.
    $reconfiguring = $false
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $current = Get-Content -LiteralPath $Path -Raw -Encoding utf8
        if ($current -and $current.Contains($marker.Open)) {
            $reconfiguring = $true
        }
    }

    # Interactive-only: the wizard is the only way to make a tool choice, so without prompts there is
    # nothing sensible to write. Warn and make no changes (no write on a first run; an existing block is
    # left intact on a re-run) rather than guessing at a configuration.
    $interactive = [bool](Get-Command Read-SpectreSelection -ErrorAction SilentlyContinue)
    if (-not $interactive) {
        Write-Warning 'Install-PwshProfile requires an interactive session (PwshSpectreConsole prompts are unavailable); no changes made. Run it in an interactive PowerShell to configure your profile.'
        return
    }

    # On a re-run, parse the existing managed block so the wizard can default to the prior choices and
    # flag tools added since (current catalog minus the recorded snapshot). A missing/old snapshot
    # leaves $newTools empty so nothing is falsely flagged "(new)".
    $priorSettings = $null
    $newTools = @()
    if ($reconfiguring) {
        $prior = Read-PwshProfileInstalledSetting -Path $Path
        if ($prior) {
            $priorSettings = $prior.Settings
            $snapshot = @($prior.ToolSnapshot)
            if ($snapshot.Count) {
                $newTools = @(Get-PwshProfileToolCatalog -Token | Where-Object { $snapshot -notcontains $_ })
            }
        }
    }

    Write-Figlet -Text 'Pwsh Profile' -Color $accent
    if (Get-Command Write-SpectreHost -ErrorAction SilentlyContinue) { Write-SpectreHost '' }
    $pathLine = '`' + $Path + '`'   # render the target path as a cyan code literal
    $intro = if ($reconfiguring) {
        "Updating the **ScrewCitySoftware.PwshProfile** bootstrap in:`n$pathLine"
    }
    else {
        "This wizard wires **ScrewCitySoftware.PwshProfile** into:`n$pathLine"
    }
    Format-PwshProfileHelpMarkup -Text $intro -Accent $accent -Code $code -Body default |
        Format-SpectrePanel -Header '◆ Profile setup' -Border Rounded -Color $accent -Expand | Out-Host

    $settings = Invoke-PwshProfileWizard -Reconfiguring:$reconfiguring -PriorSetting $priorSettings -NewTool $newTools

    # The wizard returns $null when the user cancels at the review screen — write nothing.
    if ($null -eq $settings) {
        if (Get-Command Format-SpectrePanel -ErrorAction SilentlyContinue) {
            if (Get-Command Write-SpectreHost -ErrorAction SilentlyContinue) { Write-SpectreHost '' }
            '[grey]Setup cancelled — no changes made.[/]' |
                Format-SpectrePanel -Header '• Cancelled' -Border Rounded -Color Grey -Expand | Out-Host
        }
        else {
            Write-Warning 'Install-PwshProfile: setup cancelled; no changes made.'
        }
        return
    }

    # Optional Nerd Font install (a one-time machine action; not part of the profile bootstrap).
    # Skipped under -WhatIf, since a preview must make no changes (this also installs a module).
    $fonts = @($settings.NerdFont | Where-Object { $_ })
    if ($fonts.Count -and -not $WhatIfPreference) {
        Invoke-Step "Nerd Fonts ($($fonts -join ', '))" -Icon ':gear:' {
            Import-ModuleSafe NerdFonts
            if (Get-Command Install-NerdFont -ErrorAction SilentlyContinue) {
                # Standard variant = the 'MesloLGM Nerd Font' / 'CaskaydiaCove Nerd Font' families
                # Show-NerdFontSetup recommends, and a smaller download than the default 'All'.
                Install-NerdFont -Name $fonts -Scope CurrentUser -Variant Standard
            }
            else {
                Write-Warning "Install-PwshProfile: NerdFonts module unavailable; skipped installing '$($fonts -join ', ')'."
            }
        }
    }

    # Apply the chosen winget client settings to winget's settings.json — a one-time machine action
    # like the font install, not part of the profile bootstrap. Skipped under -WhatIf (a preview must
    # make no changes), and only when the wizard supplied the winget keys.
    if ($settings.ContainsKey('WingetScope') -and -not $WhatIfPreference) {
        Invoke-Step 'Winget settings' -Icon ':gear:' {
            Set-WingetSetting -Scope $settings.WingetScope -ProgressBar $settings.WingetProgressBar `
                -AnonymizePath $settings.WingetAnonymizePath -DisableInstallNote $settings.WingetDisableInstallNote
        }
    }

    # Terminal-font guidance — display-only (runs under -WhatIf), shown every run so users know to
    # point their terminal at a Nerd Font even if they declined the install. Pass -Font only when
    # fonts were chosen so it names the installed families; otherwise it shows the recommended pairing.
    $fontSetupArgs = @{}
    if ($fonts.Count) { $fontSetupArgs.Font = $fonts }
    Show-NerdFontSetup @fontSetupArgs

    $call = Build-PwshProfileInitializeCall -Setting $settings

    if (Get-Command Format-SpectrePanel -ErrorAction SilentlyContinue) {
        $preview = Get-PwshProfileBlock -InitializeCall $call
        $preview | Format-SpectrePanel -Header "Bootstrap for $Path" -Border Rounded -Color $accent -Expand | Out-Host
    }

    # The writer carries SupportsShouldProcess, and -WhatIf/-Confirm flow into it via preference
    # variables, so the actual write stays fully gated.
    $writeArgs = @{ Path = $Path; InitializeCall = $call }
    if ($Force) { $writeArgs.Force = $true }
    $result = Write-PwshProfileBlock @writeArgs

    if (-not $WhatIfPreference -and (Get-Command Format-SpectrePanel -ErrorAction SilentlyContinue)) {
        $color = 'Green'
        $msg = switch ($result.Action) {
            'AlreadyPresent' { 'Already configured — no changes made.' }
            'BareImportPresent' {
                $color = 'Yellow'
                'A hand-written import already exists (no managed block). Left as-is — re-run with -Force to add the managed block, or run Uninstall-PwshProfile first.'
            }
            default { 'Bootstrap written. Restart your shell (or run . $PROFILE) to apply.' }
        }
        if (Get-Command Write-SpectreHost -ErrorAction SilentlyContinue) { Write-SpectreHost '' }
        $header = if ($color -eq 'Green') { '✓ Done' } else { '! Heads up' }
        $pathMarkup = Format-PwshProfileHelpMarkup -Text ('`' + $result.Path + '`') -Code $code -Body default
        "[$color]$msg[/]`n$pathMarkup" | Format-SpectrePanel -Header $header -Border Rounded -Color $color -Expand | Out-Host
    }

    if ($PassThru) { $result }
}
