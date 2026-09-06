function Read-PwshProfileInstalledSetting {
    <#
    .SYNOPSIS
        Parses an existing managed bootstrap block back into the prior run's settings plus its
        recorded tools snapshot, for re-run prefill and new-tool detection.

    .DESCRIPTION
        When Install-PwshProfile re-runs against a profile that already carries a managed block, the
        wizard should default to the choices from last time and highlight tools added to the module
        since. This helper reads that back:

          - It locates the managed region between the Get-PwshProfileMarker sentinels.
          - It AST-parses the embedded Initialize-PwshProfile call
            ([System.Management.Automation.Language.Parser]::ParseInput) and maps the bound parameters
            to a settings hashtable, keeping only the keys that were present. Which parameters it
            recognizes, and how each is parsed, come from Get-PwshProfileSettingSchema -Wizard: a
            String needs a value or sets no key, an Array is always array-wrapped so a bare -Enable
            reads as an empty selection, and a Switch is $true when bare with an explicit
            -Foo:$false honored. Runtime-only parameters are excluded — parsing one back would set a
            key nothing re-emits, which is how a hand-added -BannerFontPath used to vanish.
          - It reads the `# Tools available: a,b,c` snapshot comment (the full catalog at write time)
            into ToolSnapshot.

        It is failure-tolerant by design (it feeds an interactive setup, but must never throw): a
        missing file, a missing block, a parse error, or a missing Initialize call all return $null,
        and the caller falls back to first-run defaults.

        Returns a hashtable @{ Settings = <parsed subset>; ToolSnapshot = <string[]> } on success, or
        $null when there is nothing usable to read.

    .PARAMETER Path
        The profile file to read.

    .EXAMPLE
        $prior = Read-PwshProfileInstalledSetting -Path $PROFILE

        Returns the prior settings + tools snapshot, or $null if the profile has no managed block.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    try {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
        $content = Get-Content -LiteralPath $Path -Raw -Encoding utf8
        if ([string]::IsNullOrEmpty($content)) { return $null }

        $marker = Get-PwshProfileMarker
        $pattern = '(?s)' + [regex]::Escape($marker.Open) + '(.*?)' + [regex]::Escape($marker.Close)
        $match = [regex]::Match($content, $pattern)
        if (-not $match.Success) { return $null }
        $block = $match.Groups[1].Value

        # The recorded tools snapshot (catalog at write time) — the baseline for new-tool detection.
        $snapshot = @()
        $snapMatch = [regex]::Match($block, '(?im)^\s*#\s*Tools available:\s*(.+?)\s*$')
        if ($snapMatch.Success) {
            $snapshot = @($snapMatch.Groups[1].Value -split ',' |
                ForEach-Object { $_.Trim() } | Where-Object { $_ })
        }

        # Parse the block and find the Initialize-PwshProfile command.
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($block, [ref]$tokens, [ref]$errors)
        $cmd = $ast.FindAll({
                $args[0] -is [System.Management.Automation.Language.CommandAst] -and
                $args[0].GetCommandName() -eq 'Initialize-PwshProfile'
            }, $true) | Select-Object -First 1
        if (-not $cmd) { return $null }

        # Extract a scalar string from a value AST (constant or expandable string keep their literal
        # text, e.g. '$env:COMPUTERNAME'); fall back to the source text for anything unusual.
        function Get-ScalarFromAst {
            param($Node)
            if ($Node -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
                $Node -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
                return $Node.Value
            }
            try { return [string]$Node.SafeGetValue() } catch { return $Node.Extent.Text }
        }
        # Extract a value AST as either a scalar or an array (for -Enable a,b,c / -Enable @()).
        function Get-ValueFromAst {
            param($Node)
            if ($Node -is [System.Management.Automation.Language.ArrayLiteralAst]) {
                return @($Node.Elements | ForEach-Object { Get-ScalarFromAst $_ })
            }
            if ($Node -is [System.Management.Automation.Language.ArrayExpressionAst]) {
                # Handles `-Enable @()` (no sub-statements -> empty) and `-Enable @('Zoxide','Bat')`.
                # Tuned to the shape Build-PwshProfileInitializeCall emits, where every element is a
                # plain string literal — not a general expression evaluator.
                $items = @($Node.FindAll({
                            $args[0] -is [System.Management.Automation.Language.StringConstantExpressionAst]
                        }, $true) | ForEach-Object { $_.Value })
                return $items
            }
            Get-ScalarFromAst $Node
        }

        # Canonical-case lookup so '-bannertext' etc. still map to the proper key, plus each key's
        # parse kind — both projections of the settings schema, so what this reads back cannot drift
        # from what Build-PwshProfileInitializeCall emits. -Wizard excludes the runtime-only
        # parameters: parsing one back would re-create the BannerFontPath bug, where a value was read
        # into the settings, overlaid by the wizard, then dropped because nothing re-emits it.
        $canon = @{}
        $kind = @{}
        foreach ($row in Get-PwshProfileSettingSchema -Wizard) {
            $canon[$row.Name.ToLowerInvariant()] = $row.Name
            $kind[$row.Name] = $row.Kind
        }

        $settings = @{}
        $elements = @($cmd.CommandElements)
        for ($idx = 1; $idx -lt $elements.Count; $idx++) {
            $el = $elements[$idx]
            if ($el -isnot [System.Management.Automation.Language.CommandParameterAst]) { continue }
            $name = $canon[$el.ParameterName.ToLowerInvariant()]
            if (-not $name) { continue }

            # A value can be attached (-Foo:bar) or be the next element (-Foo bar); switches have neither.
            $argNode = $el.Argument
            if (-not $argNode -and ($idx + 1) -lt $elements.Count -and
                $elements[$idx + 1] -isnot [System.Management.Automation.Language.CommandParameterAst]) {
                $argNode = $elements[$idx + 1]
                $idx++
            }

            switch ($kind[$name]) {
                'Switch' {
                    # Present switch -> $true unless explicitly -Foo:$false. Read the boolean off the
                    # AST: the generic value stringifies, and [bool]'False' is $true, which would flip it.
                    if ($argNode) {
                        try { $settings[$name] = [bool]$argNode.SafeGetValue() }
                        catch { $settings[$name] = [bool](Get-ValueFromAst $argNode) }
                    }
                    else { $settings[$name] = $true }
                }
                'Array' {
                    # Always array-wrapped, so a bare -Enable with no value parses as an empty selection
                    # rather than a missing key.
                    $settings[$name] = @(if ($argNode) { Get-ValueFromAst $argNode })
                }
                'String' {
                    # A string parameter with no value sets no key at all — absent means "kept the default".
                    if ($argNode) { $settings[$name] = [string](Get-ValueFromAst $argNode) }
                }
            }
        }

        return @{ Settings = $settings; ToolSnapshot = $snapshot }
    }
    catch {
        Write-Warning "Read-PwshProfileInstalledSetting: could not parse the existing bootstrap ($($_.Exception.Message)); treating as a fresh setup."
        return $null
    }
}
