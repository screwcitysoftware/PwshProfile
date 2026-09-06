function Read-PwshProfileWiringTree {
    <#
    .SYNOPSIS
        Shows the grouped wiring checkbox tree and returns the settings the user checked.

    .DESCRIPTION
        Renders Get-PwshProfileWiringCatalog as a grouped Spectre multi-selection tree — Replacements
        and Keybindings — pre-checked from the supplied settings, and returns a hashtable of
        setting name -> the row's On or Off value, ready to splat over the wizard's settings.

        Every row is returned, checked or not, because a wiring choice is a two-sided answer: leaving
        `cat -> bat` unchecked means ReplaceCat = $false, not "no opinion". That is the difference
        from the tool tree this replaced, where an unchecked box meant a tool simply did not run.

        Built directly on Spectre.Console's MultiSelectionPrompt rather than
        Read-SpectreMultiSelectionGrouped, because that wrapper cannot pre-check items — and
        pre-checking is the whole point on a re-run. Three mechanics that API forces:
          - The extension methods return a NEW prompt each call, hence the $prompt = [...]::(...)
            reassignment idiom rather than plain method calls.
          - Selection is keyed by the label STRING, so labels must be unique across all groups. The
            catalog's shape enforces that and Tests/WiringCatalog.Tests.ps1 asserts it.
          - A group header is only pre-checked when every child is; a partially-checked group is left
            alone so it renders as partial rather than falsely complete.

        When PwshSpectreConsole isn't loaded at all it returns the seed unchanged, so the caller keeps
        whatever it already had rather than silently flipping every toggle off. That guard is a type
        check, so it does NOT cover a loaded-Spectre-but-non-interactive terminal: there .Show() throws,
        and the exception is deliberately allowed to propagate out of Install-PwshProfile rather than
        being swallowed. Falling back to defaults there would write a profile the user never chose,
        which is worse than failing loudly and writing nothing.

    .PARAMETER Setting
        The current settings hashtable, read to decide which boxes open checked. A row counts as
        checked when its setting equals the row's On value.

    .PARAMETER Color
        Accent color for the prompt highlight and the legend.

    .PARAMETER CodeColor
        Color for `code` spans in the legend.

    .EXAMPLE
        $chosen = Read-PwshProfileWiringTree -Setting $state.Settings -Color '#c9aaff'
        foreach ($k in $chosen.Keys) { $state.Settings[$k] = $chosen[$k] }

        Shows the tree and folds the answers back into the wizard's settings.

    .NOTES
        Returns a hashtable rather than a token list precisely because the values are not all booleans
        — ZoxideCommand comes back as 'cd' or 'z'.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [hashtable]$Setting,

        [Parameter()]
        [string]$Color,

        [Parameter()]
        [string]$CodeColor = '#5fd7ff'
    )

    $rows = @(Get-PwshProfileWiringCatalog)
    $accent = if ($Color) { $Color } else { '#c9aaff' }

    # A row is checked when its setting already holds the On value. Absent key -> unchecked.
    function Test-RowChecked {
        param($Row)
        [bool]($Setting.ContainsKey($Row.Setting) -and $Setting[$Row.Setting] -eq $Row.On)
    }

    # Non-interactive: hand back exactly what came in, so nothing is silently turned off.
    if (-not ('Spectre.Console.MultiSelectionPrompt`1' -as [type])) {
        $unchanged = @{}
        foreach ($row in $rows) {
            $unchanged[$row.Setting] = if (Test-RowChecked $row) { $row.On } else { $row.Off }
        }
        return $unchanged
    }

    # Per-row legend above the tree — a Spectre tree can't carry per-item descriptions.
    Write-PwshProfilePromptHelp @(
        'Every tool is installed and enabled. These choose which of your existing commands they take over.'
        foreach ($row in $rows) { $row.Help }
    ) -Accent $accent -Code $CodeColor

    $prompt = [Spectre.Console.MultiSelectionPrompt[string]]::new()
    $prompt.Title = 'Select the wiring to apply (Space toggles an item or a whole section; Enter submits)'
    $prompt.PageSize = 12
    $prompt.WrapAround = $true
    $prompt.Required = $false
    $prompt.HighlightStyle = [Spectre.Console.Style]::new((Get-SpectreColorValue $accent))

    $groups = @($rows | ForEach-Object { $_.Group } | Select-Object -Unique)
    foreach ($group in $groups) {
        $labels = @($rows | Where-Object Group -eq $group | ForEach-Object { $_.Label })
        $prompt = [Spectre.Console.MultiSelectionPromptExtensions]::AddChoiceGroup($prompt, $group, [string[]]$labels)
    }

    # Pre-check each already-on row. A fully-on group also needs its header checked: in Leaf mode the
    # parent box is derived from children during interaction, not at first render.
    foreach ($group in $groups) {
        $children = @($rows | Where-Object Group -eq $group)
        $checked = @($children | Where-Object { Test-RowChecked $_ })
        if ($checked.Count -eq $children.Count) {
            $prompt = [Spectre.Console.MultiSelectionPromptExtensions]::Select($prompt, $group)
        }
        foreach ($c in $checked) {
            $prompt = [Spectre.Console.MultiSelectionPromptExtensions]::Select($prompt, $c.Label)
        }
    }

    $selected = @($prompt.Show([Spectre.Console.AnsiConsole]::Console))

    $result = @{}
    foreach ($row in $rows) {
        $result[$row.Setting] = if ($selected -contains $row.Label) { $row.On } else { $row.Off }
    }
    $result
}
