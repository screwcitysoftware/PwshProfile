function Build-PwshProfileInitializeCall {
    <#
    .SYNOPSIS
        Turns a settings hashtable into the Initialize-PwshProfile command line to embed in a profile.

    .DESCRIPTION
        Renders the single line Install-PwshProfile writes into the managed bootstrap block. Every
        parameter is emitted only when it differs from the defaults, to keep the line tidy — so an
        install that customized nothing yields the bare call 'Initialize-PwshProfile'.

        The theme sets the comparison baseline. Banner branding is compared against
        Get-PwshProfileDefault for the *selected* theme, so a forestcity install that keeps the Forest
        City branding emits just "-Theme forestcity" rather than re-spelling the matching text, color
        and icon. A custom theme emits "-CustomTheme '<path>'" instead, mirroring Initialize-PwshProfile's
        mutually exclusive parameter sets.

        Strings are single-quoted (embedded quotes doubled) so a value like ':nut_and_bolt:' survives
        verbatim. -BannerText is the exception: it is double-quoted so $env:COMPUTERNAME interpolates at
        startup, with $ deliberately left unescaped.

        Banner params are omitted under -NoBanner, so a generated call never carries a flag for a
        feature that will not render.

        WHICH params to emit, how to render each, and in what order all come from
        Get-PwshProfileSettingSchema: the scalars are emitted in schema row order, then the switches in
        schema row order. The Banner column drives -NoBanner suppression, read from the same rows
        Initialize-PwshProfile reads, so the two cannot disagree about what counts as a banner
        parameter. The three rows tagged Emit 'Custom' are the exception this function deliberately
        owns by hand: the mutually exclusive Theme/CustomTheme pair, and -NoBanner's fixed slot ahead
        of the scalars it suppresses. Reordering the schema reorders every generated profile line,
        which is why Tests/Install-PwshProfile.Tests.ps1 pins the exact text.

    .PARAMETER Setting
        The settings hashtable, keyed as Get-PwshProfileDefault and the wizard produce it. Absent keys
        fall back to the default and are not emitted.

    .EXAMPLE
        Build-PwshProfileInitializeCall -Setting (Get-PwshProfileDefault)

        Returns the bare 'Initialize-PwshProfile' — nothing differs from the defaults, so nothing is
        emitted.

    .EXAMPLE
        Build-PwshProfileInitializeCall -Setting (Get-PwshProfileDefault -Theme forestcity)

        Returns 'Initialize-PwshProfile -Theme forestcity' — the branded banner color, step icon and
        bat theme all match that theme's baseline, so none of them are re-spelled.

    .EXAMPLE
        $s = Get-PwshProfileDefault; $s.ReplaceCat = $true
        Build-PwshProfileInitializeCall -Setting $s

        Returns 'Initialize-PwshProfile -ReplaceCat'.

    .EXAMPLE
        $s = Get-PwshProfileDefault; $s.NoBanner = $true
        Build-PwshProfileInitializeCall -Setting $s

        Returns 'Initialize-PwshProfile -NoBanner' — banner params are omitted.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [hashtable]$Setting
    )

    # The selected theme drives both the -Theme/-CustomTheme tokens and the banner comparison
    # baseline; 'screwcity' is the global default, so it is never emitted as -Theme.
    $theme = if ($Setting.ContainsKey('Theme') -and $Setting.Theme) { $Setting.Theme } else { 'screwcity' }
    $customTheme = if ($Setting.ContainsKey('CustomTheme')) { $Setting.CustomTheme } else { '' }
    $Default = Get-PwshProfileDefault -Theme $theme

    # Single-quote a value for safe inclusion in the generated command, doubling embedded quotes.
    function ConvertTo-QuotedValue { param($Text) "'" + ($Text -replace "'", "''") + "'" }

    # Double-quote a value so PowerShell interpolation (e.g. $env:COMPUTERNAME) happens at startup.
    # Escape backticks first, then double quotes; $ is left intact deliberately so it interpolates.
    function ConvertTo-InterpolatedValue { param($Text) '"' + ($Text -replace '`', '``' -replace '"', '`"') + '"' }

    # Resolve a key from the supplied settings, falling back to the default when absent.
    function Get-SettingValue { param($Key) if ($Setting.ContainsKey($Key)) { $Setting[$Key] } else { $Default[$Key] } }

    $parts = [System.Collections.Generic.List[string]]::new()

    $noBanner = [bool](Get-SettingValue 'NoBanner')

    # Theme selection: a custom theme path takes precedence (and is mutually exclusive with a bundled
    # -Theme); a bundled theme is emitted only when it isn't the screwcity default.
    if ($customTheme) {
        $parts.Add("-CustomTheme $(ConvertTo-QuotedValue $customTheme)")
    }
    elseif ($theme -ne 'screwcity') {
        $parts.Add("-Theme $theme")
    }

    # -NoBanner suppresses the banner; the banner params below are then omitted as moot.
    if ($noBanner) { $parts.Add('-NoBanner') }

    # Scalars: emit only when they differ from the (themed) default. The schema's declaration order IS
    # the emit order, and Where-Object preserves it, so the generated line stays byte-stable. Emit
    # 'Interpolated' is double-quoted so $env:COMPUTERNAME expands at startup; the rest are verbatim.
    # A banner param is skipped under -NoBanner, as it would have no effect.
    $schema = Get-PwshProfileSettingSchema
    foreach ($row in $schema | Where-Object { $_.Emit -in @('Scalar', 'Interpolated') }) {
        if ($noBanner -and $row.Banner) { continue }
        $v = Get-SettingValue $row.Name
        if ($v -ne $Default[$row.Name]) {
            $rendered = if ($row.Emit -eq 'Interpolated') { ConvertTo-InterpolatedValue $v }
                        else { ConvertTo-QuotedValue $v }
            $parts.Add("-$($row.Name) $rendered")
        }
    }

    # Boolean switches: a bare flag, emitted only when it is ON and differs from the default.
    foreach ($row in $schema | Where-Object { $_.Emit -eq 'Switch' }) {
        $v = Get-SettingValue $row.Name
        if ([bool]$v -ne [bool]$Default[$row.Name] -and $v) {
            $parts.Add("-$($row.Name)")
        }
    }

    # An install that customized nothing emits no parameters at all, so join conditionally rather than
    # interpolating — "Initialize-PwshProfile $()" would leave a trailing space on the bare call.
    if ($parts.Count -eq 0) { return 'Initialize-PwshProfile' }
    "Initialize-PwshProfile $($parts -join ' ')"
}
