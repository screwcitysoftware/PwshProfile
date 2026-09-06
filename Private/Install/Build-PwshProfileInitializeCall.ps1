function Build-PwshProfileInitializeCall {
    <#
    .SYNOPSIS
        Turns a settings hashtable into the Initialize-PwshProfile command line to embed in a profile.

    .DESCRIPTION
        Renders the single line Install-PwshProfile writes into the managed bootstrap block. Most
        parameters are emitted only when they differ from the defaults, to keep the line tidy. Tool
        selection is the deliberate exception: it is ALWAYS emitted explicitly (-EnableAll, -Enable with
        the chosen tokens, or -Enable @() for nothing), because that explicit pin is what stops a tool
        added in a later module version from auto-installing on the next shell.

        The theme sets the comparison baseline. Banner branding is compared against
        Get-PwshProfileDefault for the *selected* theme, so a forestcity install that keeps the Forest
        City branding emits just "-Theme forestcity" rather than re-spelling the matching text, color
        and icon. A custom theme emits "-CustomTheme '<path>'" instead, mirroring Initialize-PwshProfile's
        mutually exclusive parameter sets.

        Strings are single-quoted (embedded quotes doubled) so a value like ':nut_and_bolt:' survives
        verbatim. -BannerText is the exception: it is double-quoted so $env:COMPUTERNAME interpolates at
        startup, with $ deliberately left unescaped.

        Tool-specific params stay consistent with the selection — the bat, less and zoxide flags are
        emitted only when their tool is enabled, and banner params are omitted under -NoBanner — so a
        generated call never carries a flag for a disabled feature.

        WHICH params to emit, how to render each, and in what order all come from
        Get-PwshProfileSettingSchema: the scalars are emitted in schema row order, then the switches in
        schema row order, then the tool pin. The gating columns are read from the same rows (Tool for
        the tool coupling, Banner for -NoBanner suppression), so a new setting cannot be gated here in
        a way that disagrees with how Initialize-PwshProfile warns about it. The five rows tagged
        Emit 'Custom' are the exception this function deliberately owns by hand: the mutually exclusive
        Theme/CustomTheme pair, -NoBanner's fixed slot ahead of the scalars it suppresses, and the
        always-emitted Enable/EnableAll pin. Reordering the schema reorders every generated profile
        line, which is why Tests/Install-PwshProfile.Tests.ps1 pins the exact text.

    .PARAMETER Setting
        The settings hashtable, keyed as Get-PwshProfileDefault and the wizard produce it. Absent keys
        fall back to the default and are not emitted.

    .EXAMPLE
        Build-PwshProfileInitializeCall -Setting (Get-PwshProfileDefault)

        Returns 'Initialize-PwshProfile -Enable @()' — the default selects nothing, so it pins an empty
        enable list rather than emitting a bare call.

    .EXAMPLE
        $s = Get-PwshProfileDefault -Theme forestcity; $s.Enable = @('Zoxide', 'Bat')
        Build-PwshProfileInitializeCall -Setting $s

        Returns 'Initialize-PwshProfile -Theme forestcity -Enable Zoxide,Bat'.

    .EXAMPLE
        $s = Get-PwshProfileDefault; $s.EnableAll = $true
        Build-PwshProfileInitializeCall -Setting $s

        Returns 'Initialize-PwshProfile -EnableAll' (every current tool plus future additions).

    .EXAMPLE
        $s = Get-PwshProfileDefault; $s.Enable = @('Bat'); $s.ReplaceCat = $true
        Build-PwshProfileInitializeCall -Setting $s

        Returns 'Initialize-PwshProfile -ReplaceCat -Enable Bat' — the switch is emitted because bat is
        enabled.

    .EXAMPLE
        $s = Get-PwshProfileDefault; $s.Enable = @('Zoxide'); $s.NoBanner = $true
        Build-PwshProfileInitializeCall -Setting $s

        Returns 'Initialize-PwshProfile -NoBanner -Enable Zoxide' — banner params are omitted.
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

    # Resolve the tool selection up front: -EnableAll covers the whole catalog, otherwise the explicit
    # Enable list. It gates which tool-specific params are emitted, so a disabled tool's flags never are.
    $enableAll = [bool](Get-SettingValue 'EnableAll')
    $enableList = @(Get-SettingValue 'Enable')
    $enabledSet = if ($enableAll) { Get-PwshProfileToolCatalog -Token } else { $enableList }
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
    # A banner param is skipped under -NoBanner, and a tool-owned param when its tool is off.
    #
    # Gate on $row.Tool being truthy rather than on a map's ContainsKey: an untooled row carries
    # Tool = $null, and a map built from every row would report ContainsKey true with a $null value,
    # which -notcontains also matches — silently suppressing -StepIcon and every banner param.
    $schema = Get-PwshProfileSettingSchema
    foreach ($row in $schema | Where-Object { $_.Emit -in @('Scalar', 'Interpolated') }) {
        if ($noBanner -and $row.Banner) { continue }
        if ($row.Tool -and $enabledSet -notcontains $row.Tool) { continue }
        $v = Get-SettingValue $row.Name
        if ($v -ne $Default[$row.Name]) {
            $rendered = if ($row.Emit -eq 'Interpolated') { ConvertTo-InterpolatedValue $v }
                        else { ConvertTo-QuotedValue $v }
            $parts.Add("-$($row.Name) $rendered")
        }
    }

    # Boolean switches: a bare flag, emitted only when it is ON, differs from the default, and its
    # owning tool (if any) is enabled — the flag is a no-op otherwise. The -not $row.Tool clause cannot
    # change today's output (all three switch rows are tool-owned); it stops a future tool-less switch
    # from being silently unemittable.
    foreach ($row in $schema | Where-Object { $_.Emit -eq 'Switch' }) {
        $v = Get-SettingValue $row.Name
        if ([bool]$v -ne [bool]$Default[$row.Name] -and $v -and
            (-not $row.Tool -or $enabledSet -contains $row.Tool)) {
            $parts.Add("-$($row.Name)")
        }
    }
    # Always emitted explicitly — that is what pins the set against future-tool drift. -EnableAll for
    # "everything + future"; otherwise -Enable with the chosen tokens, or -Enable @() for nothing.
    if ($enableAll) {
        $parts.Add('-EnableAll')
    }
    elseif ($enableList.Count -gt 0) {
        $parts.Add("-Enable $($enableList -join ',')")
    }
    else {
        $parts.Add('-Enable @()')
    }

    return "Initialize-PwshProfile $($parts -join ' ')"
}
