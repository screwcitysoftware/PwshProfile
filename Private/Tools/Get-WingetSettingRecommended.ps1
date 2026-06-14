function Get-WingetSettingRecommended {
    <#
    .SYNOPSIS
        Returns the module's recommended values for the winget client settings it manages.

    .DESCRIPTION
        The single source of truth for the four winget settings' recommended defaults. Two callers use
        it: Get-WingetSettingDefault seeds its fallbacks from this (the value used when a setting isn't
        explicitly present in winget's user settings), and the install wizard's Winget step compares
        the current values against it to flag any that differ from the recommendation.

          Scope               = 'user'    (installBehavior.preferences.scope)
          ProgressBar         = 'rainbow' (visual.progressBar)
          AnonymizePath       = $true     (visual.anonymizeDisplayedPaths)
          DisableInstallNote  = $false    (installBehavior.disableInstallNotes)

        A fresh hashtable is returned each call so callers can mutate it freely.

    .EXAMPLE
        Get-WingetSettingRecommended

        Returns @{ Scope = 'user'; ProgressBar = 'rainbow'; AnonymizePath = $true; DisableInstallNote = $false }.

    .NOTES
        Keep this in sync with the settings Set-WingetSetting writes and the Winget wizard step prompts.
    #>
    [CmdletBinding()]
    param()

    @{
        Scope              = 'user'
        ProgressBar        = 'rainbow'
        AnonymizePath      = $true
        DisableInstallNote = $false
    }
}
