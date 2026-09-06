function New-PwshProfileGroupedMultiSelectionPrompt {
    <#
    .SYNOPSIS
        Builds (but does not show) a Spectre grouped multi-selection prompt from Group/Label rows.

    .DESCRIPTION
        Shared prompt-construction step behind Read-PwshProfileWiringTree and
        Read-PwshProfileUninstallTree: sets Title/PageSize/WrapAround/Required/HighlightStyle and adds
        one choice group per distinct Row.Group, via the reassign-per-call idiom the underlying
        Spectre extension methods require. Callers pre-check rows (if any) and call .Show(...)
        themselves — those steps differ enough between the two callers that folding them in here
        would just relocate the special-casing rather than remove it.

    .PARAMETER Row
        The rows to group, each carrying a Group and a Label. Labels must be unique across all groups.

    .PARAMETER Title
        The prompt's Title text.

    .PARAMETER Accent
        Accent color resolved to the prompt's HighlightStyle.

    .EXAMPLE
        $prompt = New-PwshProfileGroupedMultiSelectionPrompt -Row $rows -Title 'Pick some' -Accent '#c9aaff'

        Builds the grouped prompt; the caller still pre-checks rows and calls .Show(...).
    #>
    [CmdletBinding()]
    [OutputType([Spectre.Console.MultiSelectionPrompt[string]])]
    param(
        [Parameter(Mandatory)]
        [object[]]$Row,

        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Accent
    )

    $prompt = [Spectre.Console.MultiSelectionPrompt[string]]::new()
    $prompt.Title = $Title
    $prompt.PageSize = 12
    $prompt.WrapAround = $true
    $prompt.Required = $false
    $prompt.HighlightStyle = [Spectre.Console.Style]::new((Get-SpectreColorValue $Accent))

    $groups = @($Row | ForEach-Object { $_.Group } | Select-Object -Unique)
    foreach ($group in $groups) {
        $labels = @($Row | Where-Object Group -eq $group | ForEach-Object { $_.Label })
        $prompt = [Spectre.Console.MultiSelectionPromptExtensions]::AddChoiceGroup($prompt, $group, [string[]]$labels)
    }

    $prompt
}
