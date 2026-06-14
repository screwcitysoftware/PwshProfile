function Get-WingetSettingDefault {
    <#
    .SYNOPSIS
        Returns the effective winget client-setting values used to pre-fill the install wizard.

    .DESCRIPTION
        The single source of truth for the four winget settings the profile manages. For each one it
        returns the value explicitly set in winget's user settings if present, otherwise the module's
        fallback default. This way the install wizard's prompts come pre-filled with whatever winget
        is actually using today, and only unset settings fall back to the module's opinionated
        defaults.

        Current values are read through Microsoft's first-party Microsoft.WinGet.Client module
        (Get-WinGetUserSetting), loaded on demand via Import-ModuleSafe. Module fallback defaults
        (applied only when the key is absent):

          Scope               = 'user'    (installBehavior.preferences.scope)
          ProgressBar         = 'rainbow' (visual.progressBar)
          AnonymizePath       = $true     (visual.anonymizeDisplayedPaths)
          DisableInstallNote  = $false    (installBehavior.disableInstallNotes)

        Any failure — module unavailable, winget engine missing, unexpected output — degrades to the
        all-fallbacks result; this function never throws. A fresh hashtable is returned each call.

    .EXAMPLE
        Get-WingetSettingDefault

        Returns @{ Scope = 'user'; ProgressBar = 'rainbow'; AnonymizePath = $true; DisableInstallNote = $false }
        on a machine whose user settings set only the rainbow progress bar.

    .NOTES
        Paired with Set-WingetSetting, which writes the chosen values back (also via
        Microsoft.WinGet.Client).
    #>
    [CmdletBinding()]
    param()

    # Module fallbacks — used only where the user settings do not explicitly set the key. The
    # recommended values are the single source of truth (shared with the wizard's diff display).
    $result = Get-WingetSettingRecommended

    try {
        Import-ModuleSafe Microsoft.WinGet.Client
        if (-not (Get-Command Get-WinGetUserSetting -ErrorAction SilentlyContinue)) { return $result }
        $existing = Get-WinGetUserSetting
    }
    catch {
        return $result
    }
    if ($existing -isnot [System.Collections.IDictionary]) { return $result }

    $install = $existing['installBehavior']
    if ($install -is [System.Collections.IDictionary]) {
        $prefs = $install['preferences']
        if ($prefs -is [System.Collections.IDictionary] -and $prefs.Contains('scope')) {
            $result.Scope = [string]$prefs['scope']
        }
        if ($install.Contains('disableInstallNotes')) {
            $result.DisableInstallNote = [bool]$install['disableInstallNotes']
        }
    }

    $visual = $existing['visual']
    if ($visual -is [System.Collections.IDictionary]) {
        if ($visual.Contains('progressBar')) { $result.ProgressBar = [string]$visual['progressBar'] }
        if ($visual.Contains('anonymizeDisplayedPaths')) {
            $result.AnonymizePath = [bool]$visual['anonymizeDisplayedPaths']
        }
    }

    $result
}
