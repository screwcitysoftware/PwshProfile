function Get-PwshProfileDefault {
    <#
    .SYNOPSIS
        Returns the default profile-setup settings used by Install-PwshProfile, for a given theme.

    .DESCRIPTION
        The single source of truth for the wizard's pre-filled answers and the baseline that
        Build-PwshProfileInitializeCall compares against to decide which parameters are worth
        emitting. The keys mirror the parameters of Initialize-PwshProfile that the wizard
        can set:

          Theme, CustomTheme, BannerText, BannerColor, BannerAlignment, BannerFont, StepIcon,
          ZoxideCommand, Skip (string[]), SkipSection (string[]).

        BannerText defaults to the literal '$env:COMPUTERNAME' for every theme (it interpolates to the
        machine name at startup) — matching Initialize-PwshProfile's runtime default, so a kept default
        emits no -BannerText. The banner color and step icon are still seeded from the selected theme
        via Get-BundledThemeBranding (a forestcity default carries the green/🌳 identity, screwcity the
        purple/🔩 one). The remaining values are kept identical to Initialize-PwshProfile's own
        parameter defaults so that "all defaults" for a given theme produces a bare (or theme-only)
        Initialize-PwshProfile call. A fresh hashtable is returned on every call so callers can mutate
        it freely.

    .PARAMETER Theme
        The bundled theme whose branding seeds the banner color/icon defaults. Defaults to 'screwcity'.
        Unknown names fall back to the screwcity branding (see Get-BundledThemeBranding).

    .EXAMPLE
        Get-PwshProfileDefault

        Returns the default settings hashtable for the screwcity theme (BannerText = '$env:COMPUTERNAME',
        BannerColor = '#c9aaff', etc.).

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

    @{
        Theme           = $Theme
        CustomTheme     = ''
        # Uniform across themes; the literal interpolates to the machine name at startup.
        BannerText      = '$env:COMPUTERNAME'
        BannerColor     = $branding.BannerColor
        BannerAlignment = 'Left'
        BannerFont      = 'ANSIShadow'
        StepIcon        = $branding.StepIcon
        ZoxideCommand   = 'cd'
        Skip            = @()
        SkipSection     = @()
    }
}
