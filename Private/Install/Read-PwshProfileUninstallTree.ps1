function Read-PwshProfileUninstallTree {
    <#
    .SYNOPSIS
        Shows the grouped removal checkbox tree and returns only the rows the user checked.

    .DESCRIPTION
        Renders Get-PwshProfileRemovalInventory as a grouped Spectre multi-selection tree — WinGet
        Tools, Modules, and (when present) Windows Terminal — with NOTHING pre-checked, and returns
        just the checked subset.

        This is the one deliberate difference from Read-PwshProfileWiringTree, which it otherwise
        mirrors: a wiring row is a persisted two-sided setting, where leaving a box unchecked is itself
        a real answer (Off) that has to be recorded. A removal row is a one-shot action with no
        persisted "off" state to preserve, so there is nothing to pre-check from and nothing to record
        for an item left unchecked — the caller only needs the items that were actually chosen.

        Returns @() — no prompt shown at all — both when there is nothing installed to offer and when
        the Spectre.Console.MultiSelectionPrompt`1 type isn't loaded, the same self-contained guard
        Read-PwshProfileWiringTree uses so its caller does not need a separate interactivity probe for
        this part.

    .PARAMETER Theme
        The bundled theme whose Windows Terminal scheme to look for, forwarded to
        Get-PwshProfileRemovalInventory. Defaults to 'screwcity'.

    .PARAMETER Color
        Accent color for the prompt highlight and the intro line.

    .PARAMETER CodeColor
        Color for `code` spans in the intro line.

    .EXAMPLE
        $toRemove = Read-PwshProfileUninstallTree -Theme 'forestcity' -Color '#c9aaff'
        foreach ($item in $toRemove) { ... }

        Shows the tree and iterates only the items the user checked.

    .NOTES
        Not unit-tested here for the same reason Read-PwshProfileWiringTree isn't: its body is one
        Spectre MultiSelectionPrompt, which throws outside an interactive terminal, and importing the
        module loads PwshSpectreConsole so the type-absent branch is unreachable in this suite. What
        matters about it — that only the checked rows come back — is covered through a mock in
        Tests/Uninstall-PwshProfile.Tests.ps1.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter()]
        [string]$Theme = 'screwcity',

        [Parameter()]
        [string]$Color,

        [Parameter()]
        [string]$CodeColor = '#5fd7ff'
    )

    $rows = @(Get-PwshProfileRemovalInventory -Theme $Theme)
    if ($rows.Count -eq 0) { return @() }

    $accent = if ($Color) { $Color } else { '#c9aaff' }

    # Non-interactive: there is nothing prior to preserve, so nothing is selected.
    if (-not ('Spectre.Console.MultiSelectionPrompt`1' -as [type])) {
        return @()
    }

    Write-PwshProfilePromptHelp @(
        'Nothing is pre-selected — pick anything you want removed from this machine.'
        'Nerd Fonts are not offered here: there is no clean way to uninstall a font once installed.'
    ) -Accent $accent -Code $CodeColor

    $prompt = [Spectre.Console.MultiSelectionPrompt[string]]::new()
    $prompt.Title = 'Select items to also uninstall from this machine (Space toggles; Enter submits)'
    $prompt.PageSize = 12
    $prompt.WrapAround = $true
    $prompt.Required = $false
    $prompt.HighlightStyle = [Spectre.Console.Style]::new((Get-SpectreColorValue $accent))

    $groups = @($rows | ForEach-Object { $_.Group } | Select-Object -Unique)
    foreach ($group in $groups) {
        $labels = @($rows | Where-Object Group -eq $group | ForEach-Object { $_.Label })
        $prompt = [Spectre.Console.MultiSelectionPromptExtensions]::AddChoiceGroup($prompt, $group, [string[]]$labels)
    }

    $selected = @($prompt.Show([Spectre.Console.AnsiConsole]::Console))

    @($rows | Where-Object { $selected -contains $_.Label })
}
