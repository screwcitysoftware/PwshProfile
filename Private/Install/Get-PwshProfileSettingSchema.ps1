function Get-PwshProfileSettingSchema {
    <#
    .SYNOPSIS
        Returns the settable Initialize-PwshProfile parameters and their metadata — the single source
        of truth the defaults, the parser, the call builder, and the wizard all project from.

    .DESCRIPTION
        One row per parameter a profile or the install wizard can set. Before this existed the same
        set was restated as six hand-maintained literal lists across four files, and the param -> tool
        coupling alone was written three times with two different membership sets. Nothing forced them
        to agree, and twice they didn't: BannerFontPath was parsed but never re-emitted, so a
        hand-added value vanished on the next install; BatTheme was seeded from theme branding but
        left out of the wizard's re-seed, so switching theme wrote the old theme's bat palette into
        the new theme's profile.

        Two of the columns are strategies on different axes and are deliberately not derived from each
        other — Theme is Kind 'String' but Emit 'Custom', NoBanner is Kind 'Switch' but Emit 'Custom':

          Kind  — how Read-PwshProfileInstalledSetting PARSES the value back off the AST.
          Emit  — how Build-PwshProfileInitializeCall RENDERS it into the generated call.

        Emit 'Custom' means Build deliberately owns that key's placement (the mutually exclusive
        Theme/CustomTheme pair, and NoBanner's fixed position ahead of the scalars). Emit 'None'
        marks the runtime-only parameters: real Initialize-PwshProfile parameters
        that the wizard never writes and the parser must never read back. That is one column rather
        than a separate Wizard flag on purpose — a wizard key must be emitted or it is lost on re-run,
        and a runtime-only key must not be, so two columns could only ever disagree.

        BrandingKey names the Get-BundledThemeBranding member supplying the default, rather than a
        bare Themed boolean, because the two namespaces are not the same: FdColors takes its value
        from the branding's LsColors. Neutral is the value a branded key falls back to when the user
        supplies a custom theme, which has no bundled identity.

        ROW ORDER IS LOAD-BEARING. Build emits scalars in this order and then switches in this order,
        so reordering the array reorders every generated profile line. Tests/Install-PwshProfile.Tests.ps1
        pins the result.

    .PARAMETER Wizard
        Return only the rows a profile can carry (Emit -ne 'None'), excluding the runtime-only
        parameters. This is the set Get-PwshProfileDefault seeds, the wizard re-seeds, and
        Read-PwshProfileInstalledSetting parses.

    .EXAMPLE
        Get-PwshProfileSettingSchema

        All settable parameters, including the runtime-only ones — the set Initialize-PwshProfile
        reads to find every banner parameter, including the runtime-only BannerFontPath.

    .EXAMPLE
        (Get-PwshProfileSettingSchema -Wizard | Where-Object Kind -eq 'Switch').Name

        The switch parameters the parser must read back as booleans rather than strings.

    .EXAMPLE
        Get-PwshProfileSettingSchema -Wizard | Where-Object BrandingKey

        The branded keys — the ones the wizard re-seeds when the selected theme changes.

    .NOTES
        Rows are rebuilt on every call rather than cached, so a caller is always handed its own
        instances — Get-PwshProfileDefault's contract is that the hashtable it returns may be freely
        mutated, which a memoized schema with a reference-typed default would silently break.

        The Tool column no longer gates anything (every tool always runs), but it is kept as the
        record of which tool owns each parameter — it names the enabler a setting is forwarded to,
        and Tests/SettingSchema.Tests.ps1 holds it to real catalog tokens.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Wizard
    )

    # Declaration order is the emit order (see .DESCRIPTION). Every row declares all eight properties,
    # even where the value is $null: the suite runs under Set-StrictMode -Version Latest, where
    # reading a property a row omitted would throw rather than return $null.
    $rows = @(
        [pscustomobject]@{ Name = 'Theme'; Kind = 'String'; Default = 'screwcity'
            BrandingKey = $null; Neutral = $null; Tool = $null; Banner = $false; Emit = 'Custom' }
        [pscustomobject]@{ Name = 'CustomTheme'; Kind = 'String'; Default = ''
            BrandingKey = $null; Neutral = $null; Tool = $null; Banner = $false; Emit = 'Custom' }
        [pscustomobject]@{ Name = 'BannerText'; Kind = 'String'; Default = '$env:COMPUTERNAME'
            BrandingKey = $null; Neutral = $null; Tool = $null; Banner = $true; Emit = 'Interpolated' }
        [pscustomobject]@{ Name = 'BannerColor'; Kind = 'String'; Default = $null
            BrandingKey = 'BannerColor'; Neutral = 'Silver'; Tool = $null; Banner = $true; Emit = 'Scalar' }
        [pscustomobject]@{ Name = 'BannerAlignment'; Kind = 'String'; Default = 'Left'
            BrandingKey = $null; Neutral = $null; Tool = $null; Banner = $true; Emit = 'Scalar' }
        [pscustomobject]@{ Name = 'BannerFont'; Kind = 'String'; Default = 'ANSIShadow'
            BrandingKey = $null; Neutral = $null; Tool = $null; Banner = $true; Emit = 'Scalar' }
        [pscustomobject]@{ Name = 'BannerFontPath'; Kind = 'String'; Default = $null
            BrandingKey = $null; Neutral = $null; Tool = $null; Banner = $true; Emit = 'None' }
        [pscustomobject]@{ Name = 'StepIcon'; Kind = 'String'; Default = $null
            BrandingKey = 'StepIcon'; Neutral = ':gear:'; Tool = $null; Banner = $false; Emit = 'Scalar' }
        [pscustomobject]@{ Name = 'ZoxideCommand'; Kind = 'String'; Default = 'cd'
            BrandingKey = $null; Neutral = $null; Tool = 'Zoxide'; Banner = $false; Emit = 'Scalar' }
        [pscustomobject]@{ Name = 'BatTheme'; Kind = 'String'; Default = $null
            BrandingKey = 'BatTheme'; Neutral = 'ansi'; Tool = 'Bat'; Banner = $false; Emit = 'Scalar' }
        [pscustomobject]@{ Name = 'BatStyle'; Kind = 'String'; Default = 'numbers,changes,header'
            BrandingKey = $null; Neutral = $null; Tool = 'Bat'; Banner = $false; Emit = 'Scalar' }
        # FdColors reads the branding's LsColors — the one place the setting name and the branding
        # member name differ, which is why this column names the member instead of being a boolean.
        [pscustomobject]@{ Name = 'FdColors'; Kind = 'String'; Default = $null
            BrandingKey = 'LsColors'; Neutral = $null; Tool = 'Fd'; Banner = $false; Emit = 'None' }
        [pscustomobject]@{ Name = 'FzfColors'; Kind = 'String'; Default = $null
            BrandingKey = 'FzfColors'; Neutral = $null; Tool = 'Fzf'; Banner = $false; Emit = 'None' }
        [pscustomobject]@{ Name = 'FzfTabChord'; Kind = 'String'; Default = 'Ctrl+Spacebar'
            BrandingKey = $null; Neutral = $null; Tool = 'Fzf'; Banner = $false; Emit = 'Scalar' }
        [pscustomobject]@{ Name = 'ReplaceCat'; Kind = 'Switch'; Default = $false
            BrandingKey = $null; Neutral = $null; Tool = 'Bat'; Banner = $false; Emit = 'Switch' }
        [pscustomobject]@{ Name = 'ReplaceMore'; Kind = 'Switch'; Default = $false
            BrandingKey = $null; Neutral = $null; Tool = 'Less'; Banner = $false; Emit = 'Switch' }
        [pscustomobject]@{ Name = 'FzfGitKeyBindings'; Kind = 'Switch'; Default = $false
            BrandingKey = $null; Neutral = $null; Tool = 'Fzf'; Banner = $false; Emit = 'Switch' }
        [pscustomobject]@{ Name = 'NoBanner'; Kind = 'Switch'; Default = $false
            BrandingKey = $null; Neutral = $null; Tool = $null; Banner = $false; Emit = 'Custom' }
    )

    if ($Wizard) {
        return @($rows | Where-Object { $_.Emit -ne 'None' })
    }
    $rows
}
