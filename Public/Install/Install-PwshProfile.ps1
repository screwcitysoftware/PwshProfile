function Install-PwshProfile {
    <#
    .SYNOPSIS
        Interactive wizard that wires ScrewCitySoftware.PwshProfile into a PowerShell profile file.

    .DESCRIPTION
        Walks you through a PwshSpectreConsole wizard and writes a marker-wrapped bootstrap block — a
        guidance comment plus a tailored Initialize-PwshProfile call — into a profile file
        ($PROFILE by default). No import line is needed: invoking Initialize-PwshProfile auto-loads the
        module. This is the one-time setup companion to Initialize-PwshProfile, which then runs every
        session from that block.

        The wizard makes one forward pass — an optional Nerd Font install, winget client settings,
        theme, an optional banner, the step icon, and the per-tool options — then lands on a review
        screen where any step can be re-edited before submitting, or the whole setup cancelled without
        writing. On a re-run it parses the existing block to default each prompt to your previous
        choices.

        The Nerd Font install (NerdFonts module, CurrentUser scope, no admin), the winget settings, the
        tool CLIs, and the Windows Terminal font/scheme are one-time machine actions applied at the end
        of the run, not part of the bootstrap block — so re-running re-applies them, and -WhatIf
        previews without touching anything.

        Installing the tools here rather than at startup is what keeps the first shell fast: every
        Enable-* Install substep then short-circuits on Get-Command. The packages come from
        Get-PwshProfileToolCatalog's winget rows, not from calling the Enable-* functions, which would
        also wire this session — aliasing cat, rebinding cd — in the middle of setup.

        Your existing profile code is never destroyed:
          - A new file (and its parent directory) is created if needed.
          - An existing managed block is replaced in place, so this is safe to re-run.
          - Any other content is left intact, with the block prepended above it.
          - A profile with a bare 'Import-Module ScrewCitySoftware.PwshProfile' and no markers is left
            untouched unless -Force is given.

        This wires the module into your profile *file*; it does not install the module itself from the
        gallery (use Install-PSResource for that). Being a user-invoked setup command rather than
        silent startup, genuine errors throw. It is interactive-only: without the Spectre prompt
        cmdlets it warns that an interactive session is required and makes no changes.

    .PARAMETER Path
        The profile file to configure. Defaults to $PROFILE (current user, current host). Pass an
        explicit path to target another profile, e.g. the all-hosts or VS Code host profile.

    .PARAMETER Force
        When the target already contains a bare module import but no managed markers, prepend the
        managed block anyway instead of treating the file as already wired.

    .PARAMETER PassThru
        Emit a result object with Path, Action, and Changed. By default the command returns nothing.

    .EXAMPLE
        Install-PwshProfile

        Runs the wizard and writes the bootstrap into $PROFILE, creating it and its directory if needed.

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
        managed block is rewritten in place.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '',
        Justification = 'SupportsShouldProcess is declared so -WhatIf/-Confirm are accepted and flow via $WhatIfPreference into the gated writer Write-PwshProfileBlock (and the -not $WhatIfPreference guards on the font, winget-settings, tool-install and Windows Terminal steps); this function intentionally delegates rather than calling ShouldProcess itself. Covered by the -WhatIf tests.')]
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

    # Wizard chrome, fixed and decoupled from the prompt theme being configured.
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
    # nothing sensible to write. Warn and change nothing rather than guessing at a configuration.
    $interactive = [bool](Get-Command Read-SpectreSelection -ErrorAction SilentlyContinue)
    if (-not $interactive) {
        Write-Warning 'Install-PwshProfile requires an interactive session (PwshSpectreConsole prompts are unavailable); no changes made. Run it in an interactive PowerShell to configure your profile.'
        return
    }

    # On a re-run, parse the existing block so the wizard defaults to the prior choices. A block that
    # can't be parsed leaves $priorSettings null and the wizard falls back to first-run defaults.
    $priorSettings = $null
    if ($reconfiguring) {
        $prior = Read-PwshProfileInstalledSetting -Path $Path
        if ($prior) { $priorSettings = $prior.Settings }
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

    $settings = Invoke-PwshProfileWizard -PriorSetting $priorSettings

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

    # One-time machine action, not part of the bootstrap. Skipped under -WhatIf: a preview writes nothing.
    $fonts = @($settings.NerdFont | Where-Object { $_ })
    if ($fonts.Count -and -not $WhatIfPreference) {
        Invoke-Step "Nerd Fonts ($($fonts -join ', '))" -Icon ':gear:' {
            Import-ModuleSafe NerdFonts
            if (Get-Command Install-NerdFont -ErrorAction SilentlyContinue) {
                # The families Show-NerdFontSetup recommends, and a smaller download than 'All'.
                Install-NerdFont -Name $fonts -Scope CurrentUser -Variant Standard
            }
            else {
                Write-Warning "Install-PwshProfile: NerdFonts module unavailable; skipped installing '$($fonts -join ', ')'."
            }
        }
    }

    # One-time machine action like the font install, not part of the bootstrap. Skipped under -WhatIf,
    # and only when the wizard supplied the winget keys.
    if ($settings.ContainsKey('WingetScope') -and -not $WhatIfPreference) {
        Invoke-Step 'Winget settings' -Icon ':gear:' {
            Set-WingetSetting -Scope $settings.WingetScope -ProgressBar $settings.WingetProgressBar `
                -AnonymizePath $settings.WingetAnonymizePath -DisableInstallNote $settings.WingetDisableInstallNote
        }
    }

    # Install the tool CLIs up front, so the first shell after setup finds them already present and
    # every Enable-* Install substep short-circuits on Get-Command. Deliberately AFTER the winget
    # settings step -- scope and progress-bar preferences must be in place before installing through
    # winget -- and deliberately NOT by calling the Enable-* functions, which would also *wire* this
    # session (aliasing cat, rebinding cd) halfway through the wizard. The package metadata comes
    # from the catalog instead; Tests/ToolCatalog.Tests.ps1 holds it to what the enablers pass.
    #
    # Skipped under -WhatIf. A tool that is already present costs one Get-Command; a failed install
    # warns from Install-WingetPackageSafe and startup installs it later, so nothing here throws.
    if (-not $WhatIfPreference) {
        $wingetTools = @((Get-PwshProfileToolCatalog)['WinGet'])
        if ($wingetTools.Count -gt 0) {
            Invoke-Step "Tools ($($wingetTools.Count) packages)" -Icon ':gear:' {
                foreach ($tool in $wingetTools) {
                    # Nested step per package, so a slow first-time install is attributable.
                    Invoke-Step $tool.Token {
                        Install-WingetPackageSafe -Id $tool.PackageId -Exe $tool.Exe `
                            -CallerName 'Install-PwshProfile'
                    }
                }
            }
        }
    }

    # One-time machine action, not part of the bootstrap. Skipped under -WhatIf, and only when the
    # wizard opted in. Set-WindowsTerminalFont no-ops with a warning if settings.json isn't found.
    if ($settings.ContainsKey('SetTerminalFont') -and $settings.SetTerminalFont -and -not $WhatIfPreference) {
        Invoke-Step 'Windows Terminal font' -Icon ':gear:' {
            # Suppress host feedback (stream 6) so it can't tear the spinner; warnings (stream 3)
            # still flow through Invoke-Step's replay.
            Set-WindowsTerminalFont -FontFace 'MesloLGM Nerd Font' 6> $null
        }
    }

    # One-time machine action, not part of the bootstrap. Skipped under -WhatIf, and only when the
    # wizard opted in. Resolve the theme defensively (as Build-PwshProfileInitializeCall does) since a
    # custom theme leaves Theme as 'screwcity'.
    if ($settings.ContainsKey('InstallTerminalScheme') -and $settings.InstallTerminalScheme -and -not $WhatIfPreference) {
        Invoke-Step 'Windows Terminal scheme' -Icon ':gear:' {
            $schemeTheme = if ($settings.ContainsKey('Theme') -and $settings.Theme) { $settings.Theme } else { 'screwcity' }
            $schemeArgs = @{ Theme = $schemeTheme }
            if ($settings.ContainsKey('SetSchemeDefault') -and $settings.SetSchemeDefault) { $schemeArgs['SetDefault'] = $true }
            # Suppress host feedback (stream 6); warnings (stream 3) still reach Invoke-Step's replay.
            Install-WindowsTerminalScheme @schemeArgs 6> $null
        }
    }

    # Display-only, so it runs under -WhatIf, and every run — users need to point their terminal at a
    # Nerd Font even if they declined the install. -Font names the installed families when there are any.
    $fontSetupArgs = @{}
    if ($fonts.Count -gt 0) { $fontSetupArgs.Font = $fonts }
    Show-NerdFontSetup @fontSetupArgs

    $call = Build-PwshProfileInitializeCall -Setting $settings

    if (Get-Command Format-SpectrePanel -ErrorAction SilentlyContinue) {
        $preview = Get-PwshProfileBlock -InitializeCall $call
        $preview | Format-SpectrePanel -Header "Bootstrap for $Path" -Border Rounded -Color $accent -Expand | Out-Host
    }

    # The writer carries SupportsShouldProcess and -WhatIf/-Confirm reach it via preference variables,
    # so the actual write stays fully gated.
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
