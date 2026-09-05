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

    .PARAMETER Setting
        The settings hashtable, keyed as Get-PwshProfileDefault and the wizard produce it. Absent keys
        fall back to the default and are not emitted.

    .PARAMETER Default
        The baseline to compare against. Resolved from the setting's selected theme when omitted;
        exposed mainly for testing.

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

    # Resolve the tool selection up front: -EnableAll covers the whole catalog, otherwise the explicit
    # Enable list. It gates which tool-specific params are emitted, so a disabled tool's flags never are.
    $enableAll = [bool](& $value 'EnableAll')
    $enableList = @(& $value 'Enable')
    $enabledSet = if ($enableAll) { Get-PwshProfileToolCatalog -Token } else { $enableList }
    $noBanner = [bool](& $value 'NoBanner')

    # Theme selection: a custom theme path takes precedence (and is mutually exclusive with a bundled
    # -Theme); a bundled theme is emitted only when it isn't the screwcity default.
    if ($customTheme) {
        $parts.Add("-CustomTheme $(& $quote $customTheme)")
    }
    elseif ($theme -ne 'screwcity') {
        $parts.Add("-Theme $theme")
    }

    # -NoBanner suppresses the banner; the banner params below are then omitted as moot.
    if ($noBanner) { $parts.Add('-NoBanner') }

    # Scalars: emit only when they differ from the (themed) default. BannerText is double-quoted so it
    # interpolates at startup; the rest are verbatim. Banner params are skipped under -NoBanner.
    $bannerKeys = @('BannerText', 'BannerColor', 'BannerAlignment', 'BannerFont')
    $keyTool = @{ ZoxideCommand = 'Zoxide'; BatTheme = 'Bat'; BatStyle = 'Bat'; FzfTabChord = 'Fzf' }
    foreach ($key in @($bannerKeys + @('StepIcon', 'ZoxideCommand', 'BatTheme', 'BatStyle', 'FzfTabChord'))) {
        if ($noBanner -and $bannerKeys -contains $key) { continue }
        if ($keyTool.ContainsKey($key) -and $enabledSet -notcontains $keyTool[$key]) { continue }
        $v = & $value $key
        if ($v -ne $Default[$key]) {
            $rendered = if ($key -eq 'BannerText') { & $quoteDouble $v } else { & $quote $v }
            $parts.Add("-$key $rendered")
        }
    }

    # Boolean switches: emitted as bare flags only when set, differing from the default ($false), and
    # the owning tool is enabled (the flag is a no-op otherwise).
    $replaceCat = & $value 'ReplaceCat'
    if ([bool]$replaceCat -ne [bool]$Default['ReplaceCat'] -and $replaceCat -and $enabledSet -contains 'Bat') {
        $parts.Add('-ReplaceCat')
    }
    $replaceMore = & $value 'ReplaceMore'
    if ([bool]$replaceMore -ne [bool]$Default['ReplaceMore'] -and $replaceMore -and $enabledSet -contains 'Less') {
        $parts.Add('-ReplaceMore')
    }
    # Opt-in, so emit the bare flag only when it is ON and fzf is enabled — like -ReplaceCat above.
    $fzfGit = & $value 'FzfGitKeyBindings'
    if ([bool]$fzfGit -ne [bool]$Default['FzfGitKeyBindings'] -and $fzfGit -and $enabledSet -contains 'Fzf') {
        $parts.Add('-FzfGitKeyBindings')
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
