function Get-BundledThemeBranding {
    <#
    .SYNOPSIS
        Returns the display name, banner color, and step icon paired with a bundled theme.

    .DESCRIPTION
        Each bundled theme has a matching identity so the startup banner and step marker feel
        cohesive with the prompt colors:

          screwcity  -> 'Screw City'  / #c9aaff (signature purple) / :nut_and_bolt:   (🔩)
          forestcity -> 'Forest City' / #8fce72 (signature green)  / :deciduous_tree: (🌳)

        DisplayName is the theme's friendly label (shown in the install wizard's theme picker); it is
        NOT the banner text — the default banner text is uniformly $env:COMPUTERNAME for every theme
        (see Get-PwshProfileDefault / Initialize-PwshProfile). The step icon is stored without a
        trailing space; the separator between the glyph and the step text is added at render time
        (Get-StepIconPrefix).

        Both Initialize-PwshProfile (at startup, to fill the banner color/icon not explicitly passed)
        and Get-PwshProfileDefault (at install time, to pre-fill the wizard and seed the comparison
        baseline) resolve color/icon through here, so the two stay in sync from one source.

        Any unrecognized name — including a custom theme path chosen at install — falls back to the
        'screwcity' branding, which is the module's neutral default identity.

    .PARAMETER Name
        The bundled theme name (e.g. 'screwcity', 'forestcity'). Unknown names fall back to
        'screwcity'.

    .EXAMPLE
        Get-BundledThemeBranding -Name forestcity

        Returns @{ DisplayName = 'Forest City'; BannerColor = '#8fce72'; StepIcon = ':deciduous_tree:' }.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Name = 'screwcity'
    )

    $branding = @{
        screwcity  = @{ DisplayName = 'Screw City';  BannerColor = '#c9aaff'; StepIcon = ':nut_and_bolt:' }
        forestcity = @{ DisplayName = 'Forest City'; BannerColor = '#8fce72'; StepIcon = ':deciduous_tree:' }
    }

    if ($branding.ContainsKey($Name)) { $branding[$Name].Clone() } else { $branding['screwcity'].Clone() }
}
