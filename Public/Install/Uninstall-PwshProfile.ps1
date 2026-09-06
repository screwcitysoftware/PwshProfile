function Uninstall-PwshProfile {
    <#
    .SYNOPSIS
        Removes the ScrewCitySoftware.PwshProfile bootstrap block from a profile file.

    .DESCRIPTION
        Deletes the marker-wrapped managed block that Install-PwshProfile writes, preserving every other
        line in the file. It is the counterpart to Install-PwshProfile; to merely change settings,
        re-run Install instead, which rewrites the block in place.

        This always removes only the profile file's bootstrap block — that part never uninstalls any
        tool, font, or module, and never prompts. Additionally, when run in an interactive session with
        Spectre prompts available (the same interactive-only pattern Install-PwshProfile uses), it also
        offers a checkbox tree of the winget tools, PowerShell modules, and Windows Terminal color
        scheme actually installed on this machine, letting you choose which (if any) to remove too, so
        uninstall can bring the machine closer to its state before setup. Nothing is pre-selected — every
        removal is opt-in — and it is skipped silently outside an interactive session, so scripted calls
        are unaffected. Nerd Fonts are never offered: there is no clean way to uninstall a font once
        installed.

        Supports -WhatIf / -Confirm; every mutating action — the bootstrap-block write and each checked
        removal — is individually gated. Throws if -Path is a directory. Returns an object with Path,
        Action ('Removed' or 'NotInstalled'), Changed, and Uninstalled (one entry per item you checked,
        each with Group, Label, Kind, and whether it was actually Removed) — under -WhatIf that
        describes intent, not a change that happened.

    .PARAMETER Path
        The profile file to clean. Defaults to $PROFILE, the same default as Install-PwshProfile.

    .PARAMETER PassThru
        Emit the result object. By default the command returns nothing.

    .EXAMPLE
        Uninstall-PwshProfile

        Removes the managed bootstrap block from $PROFILE, leaving any other profile code intact, and
        (interactively) offers a checkbox of installed tools/modules/scheme to also remove.

    .EXAMPLE
        Uninstall-PwshProfile -Path $PROFILE.CurrentUserAllHosts -WhatIf

        Previews removing the block from the all-hosts profile without changing anything.

    .NOTES
        $PROFILE is host-specific — VS Code and ISE use different files. The file is rewritten as UTF-8
        without a BOM. If removing the block leaves the file empty, the empty file is left in place
        rather than deleted.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Path = $PROFILE,

        [Parameter()]
        [switch]$PassThru
    )

    if (Test-Path -LiteralPath $Path -PathType Container) {
        throw "Uninstall-PwshProfile: '$Path' is a directory, not a profile file."
    }

    $marker = Get-PwshProfileMarker

    # Read back before the block is stripped below — this is what tells the checkbox step which
    # theme's Windows Terminal scheme (if any) was actually configured.
    $priorTheme = 'screwcity'
    $prior = Read-PwshProfileInstalledSetting -Path $Path
    if ($prior -and $prior.Settings.ContainsKey('Theme') -and $prior.Settings.Theme) {
        $priorTheme = $prior.Settings.Theme
    }

    $result = [pscustomobject]@{
        Path        = $Path
        Action      = 'NotInstalled'
        Changed     = $false
        Uninstalled = @()
    }

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $existing = Get-Content -LiteralPath $Path -Raw -Encoding utf8
        if ($null -eq $existing) { $existing = '' }

        # Consume the block's closing line terminator plus one optional blank separator (the gap
        # Install inserts), leaving the rest — and the user's line endings — intact. An empty
        # replacement avoids regex $-substitution.
        $pattern = '(?s)' + [regex]::Escape($marker.Open) + '.*?' + [regex]::Escape($marker.Close) + '\r?\n?(\r?\n)?'
        $new = [regex]::Replace($existing, $pattern, '')

        if ($new -ne $existing) {
            if ($PSCmdlet.ShouldProcess($Path, 'Remove ScrewCitySoftware.PwshProfile bootstrap')) {
                Set-Content -LiteralPath $Path -Value $new -Encoding utf8 -NoNewline
            }
            $result.Action = 'Removed'
            $result.Changed = $true
        }
        elseif ($existing -match '(?im)^\s*Import-Module\s+ScrewCitySoftware\.PwshProfile\b') {
            Write-Verbose "Uninstall-PwshProfile: found a hand-written import (no managed block) in '$Path'; left untouched."
        }
    }

    if (-not $WhatIfPreference -and (Get-Command Format-SpectrePanel -ErrorAction SilentlyContinue)) {
        if ($result.Action -eq 'Removed') {
            $color = 'Green'
            $msg = 'Bootstrap removed. Fonts are left untouched; you can choose which tools/modules to remove next.'
        }
        else {
            $color = 'Yellow'
            $msg = 'No managed bootstrap block found — nothing to remove.'
        }
        if (Get-Command Write-SpectreHost -ErrorAction SilentlyContinue) { Write-SpectreHost '' }
        "[$color]$msg[/]`n[grey]$($result.Path)[/]" | Format-SpectrePanel -Header 'Uninstall' -Border Rounded -Color $color -Expand | Out-Host
    }

    # Purely additive: runs regardless of the bootstrap-block outcome above, and regardless of -WhatIf
    # (the prompt itself changes nothing; each checked removal is individually gated below). Skipped
    # silently — no warning — when Spectre prompts aren't available, so a scripted call is unaffected.
    if (Get-Command Read-SpectreSelection -ErrorAction SilentlyContinue) {
        $toRemove = @(Read-PwshProfileUninstallTree -Theme $priorTheme)
        $result.Uninstalled = @(
            foreach ($item in $toRemove) {
                $ok = $false
                switch ($item.Kind) {
                    'Tool' {
                        if ($PSCmdlet.ShouldProcess($item.Label, 'Uninstall via winget')) {
                            $ok = Uninstall-WingetPackageSafe -Id $item.Id -Exe $item.Exe -CallerName 'Uninstall-PwshProfile'
                        }
                    }
                    'Module' {
                        if ($PSCmdlet.ShouldProcess($item.Label, 'Uninstall PowerShell module')) {
                            $ok = Uninstall-ModuleSafe -Name $item.Name -CallerName 'Uninstall-PwshProfile'
                        }
                    }
                    'TerminalScheme' {
                        if ($PSCmdlet.ShouldProcess($item.Label, 'Remove Windows Terminal color scheme')) {
                            Uninstall-WindowsTerminalScheme -Theme $item.Theme
                            $ok = $true
                        }
                    }
                }
                [pscustomobject]@{ Group = $item.Group; Label = $item.Label; Kind = $item.Kind; Removed = [bool]$ok }
            }
        )
    }

    if ($PassThru) { $result }
}
