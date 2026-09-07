function Get-PwshProfileDefault {
    <#
    .SYNOPSIS
        Returns the default profile-setup settings used by Install-PwshProfile, for a given theme.

    .DESCRIPTION
        The wizard's pre-filled answers, and the baseline Build-PwshProfileInitializeCall compares
        against to decide which parameters are worth emitting.

        The key set is not written here: it is one entry per wizard-settable row of
        Get-PwshProfileSettingSchema, so it cannot drift from what the call builder emits or the
        parser reads back. This function owns the VALUES; the schema owns which keys exist.

        BannerText defaults to the literal '$env:COMPUTERNAME' for every theme (it interpolates to the
        machine name at startup) — matching Initialize-PwshProfile's runtime default, so a kept default
        emits no -BannerText. The banner color, step icon, and bat theme are seeded from the selected
        theme — the schema marks each with the branding member supplying it, so a forestcity default
        carries the green/🌳/gruvbox-dark identity and screwcity the purple/🔩/Dracula one.
        ReplaceCat, ReplaceMore, and NoBanner default to $false (the baseline), so opting in emits
        -ReplaceCat / -ReplaceMore / -NoBanner. The remaining values are kept identical to
        Initialize-PwshProfile's own parameter defaults. A fresh hashtable is returned on every call so
        callers can mutate it freely.

    .PARAMETER Theme
        The bundled theme whose branding seeds the branded defaults (banner color, step icon, bat
        theme — whichever rows carry a BrandingKey). Defaults to 'screwcity'; unknown names fall back
        to the screwcity branding (see Get-BundledThemeBranding).

    .EXAMPLE
        Get-PwshProfileDefault

        Returns the default settings hashtable for the screwcity theme (BannerText = '$env:COMPUTERNAME',
        BannerColor = '#4c81c8', etc.).

    .EXAMPLE
        Get-PwshProfileDefault -Theme forestcity

        Returns the defaults seeded with the Forest City color/icon (BannerColor = '#8fce72',
        StepIcon = ':deciduous_tree:') and the uniform BannerText = '$env:COMPUTERNAME'.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Theme = 'screwcity'
    )

    $branding = Get-BundledThemeBranding -Name $Theme

    # One entry per wizard-settable row of the settings schema, so this cannot drift from what
    # Build-PwshProfileInitializeCall emits or Read-PwshProfileInstalledSetting parses. A branded key
    # takes its value from the selected theme (BrandingKey names the branding member, which is not
    # always the setting name); everything else takes the schema's static default.
    #
    # A plain [hashtable], never [ordered]: Build-PwshProfileInitializeCall declares [hashtable]$Setting
    # and the wizard calls .Clone() on this, which OrderedDictionary does not implement.
    # Assign inside each branch rather than from an if-expression: an if used as an expression pipes
    # its result, and Enable's empty-array default would unroll to $null on the way through.
    $default = @{}
    foreach ($row in Get-PwshProfileSettingSchema -Wizard) {
        if ($row.BrandingKey) { $default[$row.Name] = $branding[$row.BrandingKey] }
        else { $default[$row.Name] = $row.Default }
    }

    # The one honest special case: Theme answers with the theme that was asked for, not the schema's
    # 'screwcity' baseline.
    $default.Theme = $Theme
    $default
}
