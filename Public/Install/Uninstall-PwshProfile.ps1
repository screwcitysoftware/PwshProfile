function Uninstall-PwshProfile {
    <#
    .SYNOPSIS
        Removes the ScrewCitySoftware.PwshProfile bootstrap block from a profile file.

    .DESCRIPTION
        Deletes the marker-wrapped managed block that Install-PwshProfile writes (the module
        import plus the Initialize-PwshProfile call between the conda-style sentinels),
        preserving every other line in the file. It is the counterpart to Install-PwshProfile;
        to merely change settings, re-run Install instead (it rewrites the block in place).

        This touches ONLY the profile file. It does NOT uninstall any tools, Nerd Fonts, or
        PowerShell modules that were installed during setup — removing the bootstrap simply stops
        the module from initializing on future sessions.

        Only the marker-delimited block is removed. A hand-written, unmanaged
        'Import-Module ScrewCitySoftware.PwshProfile' (with no markers) is left untouched, since it
        is your own code rather than the managed injection.

        Supports -WhatIf / -Confirm; the single write is the only mutating action and is fully gated.
        Throws if -Path is a directory.

        Returns one [pscustomobject] with Path, Action ('Removed' | 'NotInstalled'), and Changed
        ([bool]).

    .PARAMETER Path
        The profile file to clean. Defaults to $PROFILE (current user, current host) — the same
        default as Install-PwshProfile. $PROFILE is host-specific.

    .PARAMETER PassThru
        Emit the result object. By default the command returns nothing.

    .EXAMPLE
        Uninstall-PwshProfile

        Removes the managed bootstrap block from $PROFILE, leaving any other profile code intact.

    .EXAMPLE
        Uninstall-PwshProfile -Path $PROFILE.CurrentUserAllHosts -WhatIf

        Previews removing the block from the all-hosts profile without changing anything.

    .NOTES
        $PROFILE is host-specific (VS Code and ISE use different files). The file is rewritten as
        UTF-8 without a BOM. If removing the block leaves the file empty, the (empty) file is left
        in place rather than deleted.

        Under -WhatIf the returned object describes the action that *would* be taken (e.g.
        Action = 'Removed', Changed = $true) — the write is skipped, so the result reflects intent,
        not a change that happened.
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

    $result = [pscustomobject]@{
        Path    = $Path
        Action  = 'NotInstalled'
        Changed = $false
    }

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $existing = Get-Content -LiteralPath $Path -Raw -Encoding utf8
        if ($null -eq $existing) { $existing = '' }

        # Match the managed block and consume its closing line terminator plus one optional blank
        # separator line (the gap Install inserts above existing content), leaving everything else
        # — and the user's line endings — intact. An empty replacement avoids regex $-substitution.
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
            $msg = 'Bootstrap removed. Installed tools and fonts were left untouched.'
        }
        else {
            $color = 'Yellow'
            $msg = 'No managed bootstrap block found — nothing to remove.'
        }
        if (Get-Command Write-SpectreHost -ErrorAction SilentlyContinue) { Write-SpectreHost '' }
        "[$color]$msg[/]`n[grey]$($result.Path)[/]" | Format-SpectrePanel -Header 'Uninstall' -Border Rounded -Color $color -Expand | Out-Host
    }

    if ($PassThru) { $result }
}
