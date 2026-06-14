function Build-PwshProfileInitializeCall {
    <#
    .SYNOPSIS
        Turns a settings hashtable into the Initialize-PwshProfile command line to embed in
        a profile.

    .DESCRIPTION
        Renders the single line that Install-PwshProfile writes into the managed bootstrap
        block. To keep the generated profile tidy and resilient to future default changes, only
        the parameters that differ from the defaults are emitted — a settings object equal to the
        defaults for the screwcity theme yields a bare "Initialize-PwshProfile" with no arguments.

        The theme drives the comparison baseline: the banner branding (text/color/icon) is compared
        against Get-PwshProfileDefault for the *selected* theme, so a forestcity install that keeps
        the Forest City branding emits just "-Theme forestcity" rather than re-spelling the matching
        banner text/color/icon. A bundled theme other than screwcity emits "-Theme <name>"; a custom
        theme path emits "-CustomTheme '<path>'" (the two are mutually exclusive in the generated
        call, mirroring Initialize-PwshProfile's parameter sets).

        String values are single-quoted (embedded single quotes are doubled) so values such as
        the ':nut_and_bolt:' step icon survive verbatim. The one exception is -BannerText, which is
        double-quoted so values like $env:COMPUTERNAME interpolate at profile startup (embedded
        double quotes and backticks are backtick-escaped; $ is intentionally left unescaped). The
        -Skip / -SkipSection arrays are emitted as comma-joined tokens (their values come from a
        ValidateSet, so they need no quoting) and only when non-empty.

    .PARAMETER Setting
        The settings hashtable (keys as produced by Get-PwshProfileDefault / the wizard:
        Theme, CustomTheme, BannerText, BannerColor, BannerAlignment, BannerFont, StepIcon,
        ZoxideCommand, Skip, SkipSection). Keys that are absent fall back to the default and are
        not emitted.

    .PARAMETER Default
        The baseline to compare against. When omitted it is resolved as Get-PwshProfileDefault for
        the setting's selected theme; exposed mainly for testing.

    .EXAMPLE
        Build-PwshProfileInitializeCall -Setting (Get-PwshProfileDefault)

        Returns 'Initialize-PwshProfile' (all screwcity defaults, so no arguments).

    .EXAMPLE
        Build-PwshProfileInitializeCall -Setting (Get-PwshProfileDefault -Theme forestcity)

        Returns 'Initialize-PwshProfile -Theme forestcity' (the matching Forest City banner branding
        is the default for that theme, so it is not re-emitted).

    .EXAMPLE
        $s = Get-PwshProfileDefault; $s.BannerColor = '#00d7ff'; $s.Skip = @('Fnm', 'Xh')
        Build-PwshProfileInitializeCall -Setting $s

        Returns "Initialize-PwshProfile -BannerColor '#00d7ff' -Skip Fnm,Xh".

    .EXAMPLE
        $s = Get-PwshProfileDefault; $s.BannerText = '$env:COMPUTERNAME'
        Build-PwshProfileInitializeCall -Setting $s

        Returns 'Initialize-PwshProfile -BannerText "$env:COMPUTERNAME"' — double-quoted so the
        banner shows the machine name at startup.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [hashtable]$Setting,

        [Parameter(Position = 1)]
        [hashtable]$Default
    )

    # The selected theme drives both the -Theme/-CustomTheme tokens and the banner comparison
    # baseline; 'screwcity' is the global default, so it is never emitted as -Theme.
    $theme = if ($Setting.ContainsKey('Theme') -and $Setting.Theme) { $Setting.Theme } else { 'screwcity' }
    $customTheme = if ($Setting.ContainsKey('CustomTheme')) { $Setting.CustomTheme } else { '' }
    if (-not $PSBoundParameters.ContainsKey('Default')) { $Default = Get-PwshProfileDefault -Theme $theme }

    # Single-quote a value for safe inclusion in the generated command, doubling embedded quotes.
    $quote = { param($value) "'" + ($value -replace "'", "''") + "'" }

    # Double-quote a value so PowerShell interpolation (e.g. $env:COMPUTERNAME) happens at startup.
    # Escape backticks first, then double quotes; $ is left intact deliberately so it interpolates.
    $quoteDouble = { param($value) '"' + ($value -replace '`', '``' -replace '"', '`"') + '"' }

    # Resolve a key from the supplied settings, falling back to the default when absent.
    $value = { param($key) if ($Setting.ContainsKey($key)) { $Setting[$key] } else { $Default[$key] } }

    $parts = [System.Collections.Generic.List[string]]::new()

    # Theme selection: a custom theme path takes precedence (and is mutually exclusive with a bundled
    # -Theme); a bundled theme is emitted only when it isn't the screwcity default.
    if ($customTheme) {
        $parts.Add("-CustomTheme $(& $quote $customTheme)")
    }
    elseif ($theme -ne 'screwcity') {
        $parts.Add("-Theme $theme")
    }

    # Scalar string parameters: emit only when they differ from the (themed) default. BannerText is
    # double-quoted (interpolation); the rest are single-quoted (verbatim).
    foreach ($key in 'BannerText', 'BannerColor', 'BannerAlignment', 'BannerFont', 'StepIcon', 'ZoxideCommand') {
        $v = & $value $key
        if ($v -ne $Default[$key]) {
            $rendered = if ($key -eq 'BannerText') { & $quoteDouble $v } else { & $quote $v }
            $parts.Add("-$key $rendered")
        }
    }

    # Array parameters: emit comma-joined tokens only when non-empty (default is empty).
    foreach ($key in 'Skip', 'SkipSection') {
        $v = @(& $value $key)
        if ($v.Count -gt 0) {
            $parts.Add("-$key $($v -join ',')")
        }
    }

    if ($parts.Count -eq 0) {
        return 'Initialize-PwshProfile'
    }
    return "Initialize-PwshProfile $($parts -join ' ')"
}
