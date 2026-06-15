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
            to a settings hashtable (only the keys that were present): Theme, CustomTheme, BannerText,
            BannerColor, BannerAlignment, BannerFont, BannerFontPath, StepIcon, ZoxideCommand,
            BatTheme, BatStyle (strings); Enable (string[]); EnableAll, NoBanner, ReplaceCat,
            ReplaceMore (switches -> $true when present).
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
        $tokens = $null; $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($block, [ref]$tokens, [ref]$errors)
        $cmd = $ast.FindAll({
                $args[0] -is [System.Management.Automation.Language.CommandAst] -and
                $args[0].GetCommandName() -eq 'Initialize-PwshProfile'
            }, $true) | Select-Object -First 1
        if (-not $cmd) { return $null }

        # Extract a scalar string from a value AST (constant or expandable string keep their literal
        # text, e.g. '$env:COMPUTERNAME'); fall back to the source text for anything unusual.
        $scalar = {
            param($node)
            if ($node -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
                $node -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
                return $node.Value
            }
            try { return [string]$node.SafeGetValue() } catch { return $node.Extent.Text }
        }
        # Extract a value AST as either a scalar or an array (for -Enable a,b,c / -Enable @()).
        $value = {
            param($node)
            if ($node -is [System.Management.Automation.Language.ArrayLiteralAst]) {
                return @($node.Elements | ForEach-Object { & $scalar $_ })
            }
            if ($node -is [System.Management.Automation.Language.ArrayExpressionAst]) {
                # Handles the @(...) form, e.g. `-Enable @()` (no sub-statements -> empty) or
                # `-Enable @('Zoxide','Bat')`. This is tuned to the array shape Build-PwshProfile-
                # InitializeCall emits, where every element is a plain string literal; the recursive
                # FindAll harvests those constants. It is NOT a general expression evaluator — for an
                # arbitrary @(...) it would also collect strings nested in sub-expressions.
                $items = @($node.FindAll({
                            $args[0] -is [System.Management.Automation.Language.StringConstantExpressionAst]
                        }, $true) | ForEach-Object { $_.Value })
                return $items
            }
            & $scalar $node
        }

        $stringParams = @('Theme', 'CustomTheme', 'BannerText', 'BannerColor', 'BannerAlignment',
            'BannerFont', 'BannerFontPath', 'StepIcon', 'ZoxideCommand', 'BatTheme', 'BatStyle')
        $switchParams = @('EnableAll', 'NoBanner', 'ReplaceCat', 'ReplaceMore')

        # Canonical-case lookup so '-bannertext' etc. still map to the proper key.
        $canon = @{}
        foreach ($p in $stringParams + $switchParams + 'Enable') { $canon[$p.ToLowerInvariant()] = $p }

        $settings = @{}
        $elements = @($cmd.CommandElements)
        for ($idx = 1; $idx -lt $elements.Count; $idx++) {
            $el = $elements[$idx]
            if ($el -isnot [System.Management.Automation.Language.CommandParameterAst]) { continue }
            $name = $canon[$el.ParameterName.ToLowerInvariant()]
            if (-not $name) { continue }

            # A value can be attached (-Foo:bar) or be the next element (-Foo bar). Switches usually
            # have neither.
            $argNode = $el.Argument
            if (-not $argNode -and ($idx + 1) -lt $elements.Count -and
                $elements[$idx + 1] -isnot [System.Management.Automation.Language.CommandParameterAst]) {
                $argNode = $elements[$idx + 1]
                $idx++
            }

            if ($switchParams -contains $name) {
                # Present switch -> $true unless explicitly -Foo:$false.
                if ($argNode) { $settings[$name] = [bool](& $value $argNode) }
                else { $settings[$name] = $true }
            }
            elseif ($name -eq 'Enable') {
                $settings.Enable = @(if ($argNode) { & $value $argNode })
            }
            elseif ($argNode) {
                $settings[$name] = [string](& $value $argNode)
            }
        }

        return @{ Settings = $settings; ToolSnapshot = $snapshot }
    }
    catch {
        Write-Warning "Read-PwshProfileInstalledSetting: could not parse the existing bootstrap ($($_.Exception.Message)); treating as a fresh setup."
        return $null
    }
}
