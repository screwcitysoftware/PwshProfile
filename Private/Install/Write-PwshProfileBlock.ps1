function Write-PwshProfileBlock {
    <#
    .SYNOPSIS
        Writes (or updates) the ScrewCitySoftware.PwshProfile bootstrap block in a profile file,
        preserving any existing content.

    .DESCRIPTION
        The safety-critical file writer behind Install-PwshProfile. It places a marker-wrapped
        bootstrap block (built by Get-PwshProfileBlock — markers, a short guidance comment, the
        module import, and the supplied Initialize-PwshProfile call) into the target file
        without ever destroying surrounding code:

          # >>> ScrewCitySoftware.PwshProfile bootstrap >>>
          # Managed by Install-PwshProfile. Re-run it to change these settings, or run
          # Uninstall-PwshProfile to remove this block (or just delete these marker lines
          # yourself). Manual edits between the >>> / <<< markers are overwritten on the next
          # Install — put your own code outside them.
          Import-Module ScrewCitySoftware.PwshProfile

          <InitializeCall>
          # <<< ScrewCitySoftware.PwshProfile bootstrap <<<

        Behavior by file state:
          - Missing file        -> creates the parent directory if needed and writes the block.
          - Empty file          -> writes the block (no leading blank line).
          - Managed block found  (both markers) -> replaces it in place, leaving everything above
                                  and below untouched (this is the re-run path).
          - Bare 'Import-Module ScrewCitySoftware.PwshProfile' present, no markers -> treated as
                                  already wired; nothing is written unless -Force, which prepends
                                  the managed block.
          - Other existing file -> prepends the block (a blank separator line, then the original
                                  content verbatim).

        Writes UTF-8 without a BOM (PowerShell 7's 'utf8' encoding). Existing content is preserved
        byte-for-byte except a leading BOM, which is dropped. Supports -WhatIf / -Confirm; the
        single write is the only mutating action and is fully gated. Throws if -Path is a directory.

        Returns one [pscustomobject] with Path, Action ('Created' | 'Prepended' | 'Replaced' |
        'ForcePrepended' | 'AlreadyPresent' | 'BareImportPresent'), and Changed ([bool]).
        'BareImportPresent' means a hand-written import (no managed markers) was found and left as
        is — the requested settings were NOT applied; pass -Force to add the managed block anyway.
        Under -WhatIf the result describes the action that *would* be taken (Action/Changed reflect
        intent); the write itself is skipped.

    .PARAMETER Path
        The profile file to write to.

    .PARAMETER InitializeCall
        The Initialize-PwshProfile command line to embed (as produced by
        Build-PwshProfileInitializeCall).

    .PARAMETER Force
        When the file already contains a bare module import but no managed markers, prepend the
        managed block anyway instead of treating the file as already wired.

    .EXAMPLE
        Write-PwshProfileBlock -Path $PROFILE -InitializeCall 'Initialize-PwshProfile'

        Writes the default bootstrap into $PROFILE, creating it (and its directory) if needed.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$InitializeCall,

        [Parameter()]
        [switch]$Force
    )

    $marker = Get-PwshProfileMarker
    $markerOpen  = $marker.Open
    $markerClose = $marker.Close
    $nl = [Environment]::NewLine

    $block = Get-PwshProfileBlock -InitializeCall $InitializeCall

    if (Test-Path -LiteralPath $Path -PathType Container) {
        throw "Write-PwshProfileBlock: '$Path' is a directory, not a profile file."
    }

    $exists = Test-Path -LiteralPath $Path -PathType Leaf
    $existing = ''
    if ($exists) {
        $existing = Get-Content -LiteralPath $Path -Raw -Encoding utf8
        if ($null -eq $existing) { $existing = '' }
    }

    # Locate an existing managed block (open marker through close marker, inclusive). Match the
    # whole region so a re-run can splice in the new block without disturbing the rest of the file.
    $blockPattern = '(?s)' + [regex]::Escape($markerOpen) + '.*?' + [regex]::Escape($markerClose)
    $match = [regex]::Match($existing, $blockPattern)
    $hasBareImport = $existing -match '(?im)^\s*Import-Module\s+ScrewCitySoftware\.PwshProfile\b'

    if ($match.Success) {
        # Re-run: replace just the managed block, preserving everything before and after (including
        # the user's original line endings). Remove/Insert avoids .NET regex replacement-string
        # interpretation of any '$' in the embedded call.
        $new = $existing.Remove($match.Index, $match.Length).Insert($match.Index, $block)
        $provisional = 'Replaced'
    }
    elseif ($hasBareImport -and -not $Force) {
        # Already wired by hand (no managed markers); leave the file untouched. This is distinct
        # from AlreadyPresent: the requested settings were not applied.
        $new = $existing
        $provisional = 'BareImportPresent'
    }
    elseif (-not $exists -or [string]::IsNullOrEmpty($existing)) {
        $new = $block + $nl
        $provisional = if (-not $exists) { 'Created' } else { 'Prepended' }
    }
    else {
        # Prepend the block, then a blank separator, then the original content verbatim.
        $new = $block + $nl + $nl + $existing
        $provisional = if ($hasBareImport) { 'ForcePrepended' } else { 'Prepended' }
    }

    $changed = $new -ne $existing
    # Preserve the distinct bare-import action when unchanged; otherwise an unchanged write is
    # simply "already present" (e.g. a re-run whose block matched byte-for-byte).
    $action = if ($changed) { $provisional }
              elseif ($provisional -eq 'BareImportPresent') { 'BareImportPresent' }
              else { 'AlreadyPresent' }

    if ($changed -and $PSCmdlet.ShouldProcess($Path, "Write ScrewCitySoftware.PwshProfile bootstrap ($action)")) {
        $parent = Split-Path -Path $Path -Parent
        if ($parent -and -not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Set-Content -LiteralPath $Path -Value $new -Encoding utf8 -NoNewline
    }

    [pscustomobject]@{
        Path    = $Path
        Action  = $action
        Changed = $changed
    }
}
