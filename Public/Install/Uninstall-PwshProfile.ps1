function Uninstall-PwshProfile {
    <#
    .SYNOPSIS
        Removes the ScrewCitySoftware.PwshProfile bootstrap block from a profile file.

    .DESCRIPTION
        Deletes the marker-wrapped managed block that Install-PwshProfile writes, preserving every other
        line in the file. It is the counterpart to Install-PwshProfile; to merely change settings,
        re-run Install instead, which rewrites the block in place.

        This touches only the profile file. It does NOT uninstall any tools, Nerd Fonts, or PowerShell
        modules installed during setup — removing the bootstrap simply stops the module initializing in
        future sessions. A hand-written, unmarked 'Import-Module ScrewCitySoftware.PwshProfile' is left
        untouched, since that is your own code rather than the managed injection.

        Supports -WhatIf / -Confirm; the single write is the only mutating action and is fully gated.
        Throws if -Path is a directory. Returns an object with Path, Action ('Removed' or
        'NotInstalled') and Changed — under -WhatIf that describes intent, not a change that happened.

    .PARAMETER Path
        The profile file to clean. Defaults to $PROFILE, the same default as Install-PwshProfile.

    .PARAMETER PassThru
        Emit the result object. By default the command returns nothing.

    .EXAMPLE
        Uninstall-PwshProfile

        Removes the managed bootstrap block from $PROFILE, leaving any other profile code intact.

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

    $result = [pscustomobject]@{
        Path    = $Path
        Action  = 'NotInstalled'
        Changed = $false
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
