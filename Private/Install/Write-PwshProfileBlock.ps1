function Write-PwshProfileBlock {
    <#
    .SYNOPSIS
        Writes (or updates) the ScrewCitySoftware.PwshProfile bootstrap block in a profile file,
        preserving any existing content.

    .DESCRIPTION
        The safety-critical file writer behind Install-PwshProfile. It places a marker-wrapped block
        (built by Get-PwshProfileBlock — markers, a guidance comment, and the supplied
        Initialize-PwshProfile call) into the target file without ever destroying surrounding code.

        Behavior by file state:
          - Missing file  -> creates the parent directory if needed and writes the block.
          - Empty file    -> writes the block with no leading blank line.
          - Managed block -> replaces it in place, leaving everything above and below untouched. This
                             is the re-run path.
          - Bare import, no markers -> treated as already wired; nothing is written unless -Force,
                             which prepends the managed block.
          - Anything else -> prepends the block, a blank separator, then the original content verbatim.

        Writes UTF-8 without a BOM. Existing content is preserved byte-for-byte except a leading BOM,
        which is dropped. Supports -WhatIf / -Confirm; the single write is the only mutating action and
        is fully gated. Throws if -Path is a directory.

        Returns one object with Path, Action ('Created', 'Prepended', 'Replaced', 'ForcePrepended',
        'AlreadyPresent' or 'BareImportPresent') and Changed. 'BareImportPresent' means a hand-written
        import was found and left alone — the requested settings were NOT applied; pass -Force to add
        the block anyway. Under -WhatIf the result describes what *would* happen and no write occurs.

    .PARAMETER Path
        The profile file to write to.

    .PARAMETER InitializeCall
        The Initialize-PwshProfile command line to embed, as produced by Build-PwshProfileInitializeCall.

    .PARAMETER Force
        When the file already contains a bare module import but no managed markers, prepend the managed
        block anyway instead of treating the file as already wired.

    .EXAMPLE
        Write-PwshProfileBlock -Path $PROFILE -InitializeCall 'Initialize-PwshProfile'

        Writes the default bootstrap into $PROFILE, creating it and its directory if needed.
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

    # Match the whole marker region so a re-run can splice in a new block without disturbing the file.
    $blockPattern = '(?s)' + [regex]::Escape($markerOpen) + '.*?' + [regex]::Escape($markerClose)
    $match = [regex]::Match($existing, $blockPattern)
    $hasBareImport = $existing -match '(?im)^\s*Import-Module\s+ScrewCitySoftware\.PwshProfile\b'

    if ($match.Success) {
        # Re-run: replace just the managed block, preserving the rest (and its line endings).
        # Remove/Insert avoids .NET regex interpreting any '$' in the embedded call.
        $new = $existing.Remove($match.Index, $match.Length).Insert($match.Index, $block)
        $provisional = 'Replaced'
    }
    elseif ($hasBareImport -and -not $Force) {
        # Wired by hand (no markers) — leave it alone. Distinct from AlreadyPresent: nothing was applied.
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
    # An unchanged write is "already present" unless it was the distinct bare-import case.
    $action = if ($changed) { $provisional }
              elseif ($provisional -eq 'BareImportPresent') { 'BareImportPresent' }
              else { 'AlreadyPresent' }

    if ($changed -and $PSCmdlet.ShouldProcess($Path, "Write ScrewCitySoftware.PwshProfile bootstrap ($action)")) {
        $parent = Split-Path -Path $Path -Parent
        if ($parent -and -not (Test-Path -LiteralPath $parent)) {
            $null = New-Item -ItemType Directory -Path $parent -Force
        }
        Set-Content -LiteralPath $Path -Value $new -Encoding utf8 -NoNewline
    }

    [pscustomobject]@{
        Path    = $Path
        Action  = $action
        Changed = $changed
    }
}
