function Set-WingetSetting {
    <#
    .SYNOPSIS
        Merges a curated set of client preferences into winget's user settings.

    .DESCRIPTION
        Writes the winget client settings the profile manages, delegating the actual read and write
        to Microsoft's first-party Microsoft.WinGet.Client module (Get-WinGetUserSetting /
        Set-WinGetUserSetting). It reads the current user settings, sets only the keys you pass into
        their nested objects (creating installBehavior / visual / preferences as needed), and writes
        the full object back, so unrelated settings and the $schema key are preserved. Only the
        parameters you pass are changed.

        The module is loaded on demand via Import-ModuleSafe (installed CurrentUser if absent), so it
        is not a hard dependency of profile startup. This is a user-invoked configuration command, but
        it is failure-tolerant by design: if the module can't be loaded or the write fails it emits a
        warning rather than throwing, so it can be called from profile setup without aborting it. It
        honors -WhatIf/-Confirm, so a preview makes no changes.

    .PARAMETER Scope
        Default install scope written to installBehavior.preferences.scope: 'user' or 'machine'.
        'user' prefers a per-user installer (no admin prompt) and falls back to machine when a package
        offers no per-user option — it does not hard-require user scope, so installs don't fail.

    .PARAMETER ProgressBar
        Progress-bar style written to visual.progressBar: 'accent', 'rainbow', 'retro', 'sixel', or
        'disabled'.

    .PARAMETER AnonymizePath
        Whether to set visual.anonymizeDisplayedPaths — replaces known folders with their environment
        variable names (e.g. %LOCALAPPDATA%) in winget output.

    .PARAMETER DisableInstallNote
        Whether to set installBehavior.disableInstallNotes — suppresses the notes some packages print
        after a successful install.

    .EXAMPLE
        Set-WingetSetting -Scope user -ProgressBar rainbow -AnonymizePath $true -DisableInstallNote $false

        Defaults new installs to user scope, keeps the rainbow progress bar, anonymizes displayed
        paths, and leaves install notes enabled — merging into the existing user settings.

    .EXAMPLE
        Set-WingetSetting -Scope machine -WhatIf

        Previews changing only the default scope to machine, without writing anything.

    .NOTES
        Pairs with Get-WingetSettingDefault, which reads the current values back for the install
        wizard's pre-fills. Both go through Microsoft.WinGet.Client.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [ValidateSet('user', 'machine')]
        [string]$Scope,

        [Parameter()]
        [ValidateSet('accent', 'rainbow', 'retro', 'sixel', 'disabled')]
        [string]$ProgressBar,

        [Parameter()]
        [bool]$AnonymizePath,

        [Parameter()]
        [bool]$DisableInstallNote
    )

    try {
        Import-ModuleSafe Microsoft.WinGet.Client
        if (-not (Get-Command Set-WinGetUserSetting -ErrorAction SilentlyContinue)) {
            Write-Warning 'Set-WingetSetting: Microsoft.WinGet.Client is unavailable; no changes made.'
            return
        }

        # Read the current user settings (a nested hashtable incl. $schema) so we can write the full
        # object back — preserving every key we don't manage, regardless of merge semantics.
        $current = Get-WinGetUserSetting
        if ($current -isnot [System.Collections.IDictionary]) { $current = @{} }
        if (-not $current.Contains('$schema')) {
            $current['$schema'] = 'https://aka.ms/winget-settings.schema.json'
        }

        # Return (creating if needed) the nested dictionary at $key under $parent.
        $ensureNode = {
            param($parent, $key)
            if ($parent[$key] -isnot [System.Collections.IDictionary]) { $parent[$key] = @{} }
            $parent[$key]
        }

        if ($PSBoundParameters.ContainsKey('Scope')) {
            $prefs = & $ensureNode (& $ensureNode $current 'installBehavior') 'preferences'
            $prefs['scope'] = $Scope
        }
        if ($PSBoundParameters.ContainsKey('DisableInstallNote')) {
            (& $ensureNode $current 'installBehavior')['disableInstallNotes'] = $DisableInstallNote
        }
        if ($PSBoundParameters.ContainsKey('ProgressBar')) {
            (& $ensureNode $current 'visual')['progressBar'] = $ProgressBar
        }
        if ($PSBoundParameters.ContainsKey('AnonymizePath')) {
            (& $ensureNode $current 'visual')['anonymizeDisplayedPaths'] = $AnonymizePath
        }

        if ($PSCmdlet.ShouldProcess('winget user settings', 'Update')) {
            Set-WinGetUserSetting -UserSettings $current | Out-Null
        }
    }
    catch {
        Write-Warning "Set-WingetSetting: failed to update winget user settings: $($_.Exception.Message)"
    }
}
