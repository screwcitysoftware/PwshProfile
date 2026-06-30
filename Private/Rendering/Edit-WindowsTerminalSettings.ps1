function Edit-WindowsTerminalSettings {
    <#
    .SYNOPSIS
        Adds or removes a color scheme, or sets the default profile font, in a Windows Terminal
        settings.json file.

    .DESCRIPTION
        The shared read-modify-write engine behind Install-WindowsTerminalScheme,
        Uninstall-WindowsTerminalScheme, and Set-WindowsTerminalFont, factored out so the backup +
        (de)serialize logic lives in one place and stays unit-testable.

        It reads the file, parses it (ConvertFrom-Json), then either edits the `schemes` array by
        scheme `name` (idempotent — an add replaces any same-named scheme rather than duplicating it;
        a remove drops the match) or sets profiles.defaults.font.face. It backs the original up to
        "<path>.bak", then writes the result back as UTF-8 (no BOM) via ConvertTo-Json. The caller is
        expected to have gated the call behind its own ShouldProcess, so this engine performs the
        write unconditionally.

        JSONC caveat: settings.json may contain // comments and trailing commas. ConvertFrom-Json
        tolerates them on read, but the parse -> reserialize round-trip does not reproduce comments
        or the original hand-formatting. The .bak backup written before the rewrite is the safety net.

    .PARAMETER Path
        Path to the settings.json file to edit. Must exist.

    .PARAMETER Scheme
        (Add set) The color scheme to add or replace, as a hashtable in Windows Terminal's scheme
        shape (its `name` key identifies it for idempotent replace).

    .PARAMETER SetDefault
        (Add set) When set, also point profiles.defaults.colorScheme at the scheme's name so it
        applies immediately. Skipped with a warning if the file's `profiles` isn't an editable object.

    .PARAMETER RemoveName
        (Remove set) The `name` of the scheme to remove.

    .PARAMETER FontFace
        (Font set) The font family name to set as profiles.defaults.font.face (e.g.
        'MesloLGM Nerd Font'). Skipped with a warning if the file's `profiles` isn't an editable
        object.

    .EXAMPLE
        Edit-WindowsTerminalSettings -Path $p -Scheme $scheme -SetDefault

    .EXAMPLE
        Edit-WindowsTerminalSettings -Path $p -RemoveName 'Screw City'

    .EXAMPLE
        Edit-WindowsTerminalSettings -Path $p -FontFace 'MesloLGM Nerd Font'

    .NOTES
        Returns a result object describing what happened:
          Add    -> @{ Action = 'Added' | 'Replaced' }
          Remove -> @{ Action = 'Removed' | 'NotFound'; StillReferenced = <bool> }
          Font   -> @{ Action = 'SetFont'; FontFace = <string> }
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '',
        Justification = '"Settings" names Windows Terminal''s settings.json file, a proper-noun plural; a singular "Setting" would misname the whole-file target this helper edits.')]
    [CmdletBinding(DefaultParameterSetName = 'Add')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path,

        [Parameter(Mandatory, ParameterSetName = 'Add')]
        [hashtable]$Scheme,

        [Parameter(ParameterSetName = 'Add')]
        [switch]$SetDefault,

        [Parameter(Mandatory, ParameterSetName = 'Remove')]
        [string]$RemoveName,

        [Parameter(Mandatory, ParameterSetName = 'Font')]
        [string]$FontFace
    )

    $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($raw)) {
        $settings = [pscustomobject]@{}
    }
    else {
        try {
            $settings = $raw | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            throw "Edit-WindowsTerminalSettings: could not parse '$Path' as JSON: $($_.Exception.Message)"
        }
    }

    if ($PSCmdlet.ParameterSetName -eq 'Add') {
        $existing = if ($settings.PSObject.Properties['schemes']) { @($settings.schemes) } else { @() }
        $name = $Scheme['name']
        $replaced = [bool]($existing | Where-Object { $_.name -eq $name })
        $kept = @($existing | Where-Object { $_.name -ne $name })
        $newSchemes = @($kept) + ([pscustomobject]$Scheme)
        $action = if ($replaced) { 'Replaced' } else { 'Added' }
        $result = @{ Action = $action }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'Remove') {
        $existing = if ($settings.PSObject.Properties['schemes']) { @($settings.schemes) } else { @() }
        $name = $RemoveName
        $found = [bool]($existing | Where-Object { $_.name -eq $name })
        $newSchemes = @($existing | Where-Object { $_.name -ne $name })

        # Detect whether the removed scheme is still wired up as an active colorScheme.
        $stillReferenced = $false
        if ($settings.PSObject.Properties['profiles']) {
            $profiles = $settings.profiles
            if ($profiles.PSObject.Properties['defaults'] -and $profiles.defaults.PSObject.Properties['colorScheme'] -and $profiles.defaults.colorScheme -eq $name) {
                $stillReferenced = $true
            }
            if ($profiles.PSObject.Properties['list']) {
                foreach ($p in @($profiles.list)) {
                    if ($p.PSObject.Properties['colorScheme'] -and $p.colorScheme -eq $name) { $stillReferenced = $true }
                }
            }
        }
        $action = if ($found) { 'Removed' } else { 'NotFound' }
        $result = @{ Action = $action; StillReferenced = $stillReferenced }
    }
    else {
        # Font set — sets profiles.defaults.font.face only; the schemes array is left untouched.
        $result = @{ Action = 'SetFont'; FontFace = $FontFace }
    }

    # Write back the (possibly empty) schemes array — Add/Remove only; the Font set touches no schemes.
    if ($PSCmdlet.ParameterSetName -ne 'Font') {
        if ($settings.PSObject.Properties['schemes']) {
            $settings.schemes = $newSchemes
        }
        else {
            $settings | Add-Member -NotePropertyName 'schemes' -NotePropertyValue $newSchemes
        }
    }

    if (($PSCmdlet.ParameterSetName -eq 'Add' -and $SetDefault) -or $PSCmdlet.ParameterSetName -eq 'Font') {
        if (-not $settings.PSObject.Properties['profiles']) {
            $settings | Add-Member -NotePropertyName 'profiles' -NotePropertyValue ([pscustomobject]@{})
        }
        if ($settings.profiles -is [System.Management.Automation.PSCustomObject]) {
            $profiles = $settings.profiles
            if (-not $profiles.PSObject.Properties['defaults']) {
                $profiles | Add-Member -NotePropertyName 'defaults' -NotePropertyValue ([pscustomobject]@{})
            }
            $defaults = $profiles.defaults
            if ($PSCmdlet.ParameterSetName -eq 'Font') {
                # Ensure profiles.defaults.font is an object, then set/add its `face`.
                if (-not $defaults.PSObject.Properties['font']) {
                    $defaults | Add-Member -NotePropertyName 'font' -NotePropertyValue ([pscustomobject]@{})
                }
                if ($defaults.font -is [System.Management.Automation.PSCustomObject]) {
                    $font = $defaults.font
                    if ($font.PSObject.Properties['face']) {
                        $font.face = $FontFace
                    }
                    else {
                        $font | Add-Member -NotePropertyName 'face' -NotePropertyValue $FontFace
                    }
                }
                else {
                    Write-Warning "Edit-WindowsTerminalSettings: 'profiles.defaults.font' in '$Path' isn't an object; left profiles.defaults.font.face unchanged."
                }
            }
            elseif ($defaults.PSObject.Properties['colorScheme']) {
                $defaults.colorScheme = $name
            }
            else {
                $defaults | Add-Member -NotePropertyName 'colorScheme' -NotePropertyValue $name
            }
        }
        else {
            $field = if ($PSCmdlet.ParameterSetName -eq 'Font') { 'font.face' } else { 'colorScheme' }
            Write-Warning "Edit-WindowsTerminalSettings: 'profiles' in '$Path' isn't an object; left profiles.defaults.$field unchanged."
        }
    }

    # Back up the original before overwriting, then write.
    Copy-Item -LiteralPath $Path -Destination "$Path.bak" -Force
    $json = $settings | ConvertTo-Json -Depth 32
    Set-Content -LiteralPath $Path -Value $json -Encoding utf8

    [pscustomobject]$result
}
