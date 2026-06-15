function Read-PwshProfileFeatureTree {
    <#
    .SYNOPSIS
        Prompts the user with a grouped, all-checked-by-default feature tree and returns the
        feature tokens left enabled.

    .DESCRIPTION
        Drives the Install-PwshProfile wizard's feature step. The features are grouped under three
        startup sections — Shell, Prompt, Tools — so the user can toggle an individual feature or a
        whole section at once. Shell completions live under Tools (they are operations on the tools).
        Every feature starts CHECKED; unchecking one opts it out (the wizard maps the complement to
        -Skip / -SkipSection).

        oh-my-posh is deliberately absent from the tree: it has no skip switch and always runs, so
        listing it would be a checkbox that does nothing. Above the prompt a grey legend
        (Write-PwshProfilePromptHelp) describes each feature in one line — including the note that
        oh-my-posh is always enabled — since the Spectre tree can't carry per-item descriptions.

        The grouped multi-selection is built directly on the Spectre.Console MultiSelectionPrompt
        API rather than Read-SpectreMultiSelectionGrouped, because that wrapper cannot pre-check
        items (and "all on by default" is the whole point here). The prompt's string values are the
        human-readable feature labels; this function maps the returned labels back to their tokens.

        If the Spectre prompt types are unavailable (non-interactive host), it degrades by returning
        every feature token — i.e. everything enabled — matching the module's non-interactive
        fallback elsewhere.

    .PARAMETER Enabled
        A hashtable mapping each feature token (PSReadLine, TerminalIcons, PoshGit, Zoxide, Fzf, Fnm,
        Xh, Bat, Fd, Completions) to a boolean for its initial checked state. Missing/true tokens start checked.
        On the first wizard pass every token is enabled; when the step is re-edited from the review
        hub, the caller passes the current state so prior choices are preserved.

    .PARAMETER Color
        The accent color for the prompt's highlight style and the **tool name** spans in the legend,
        as a string — a hex value like '#c9aaff' or a Spectre color name like 'Silver'. Converted to a
        Spectre.Console.Color via Get-SpectreColorValue for the highlight style.

    .PARAMETER CodeColor
        The color for `code literal` spans (commands, cmdlets) in the legend, as a hex value or Spectre
        color name. Defaults to a soft cyan (#5fd7ff).

    .EXAMPLE
        Read-PwshProfileFeatureTree -Enabled @{ PSReadLine = $true; Fnm = $false } -Color '#c9aaff'

        Shows the tree with everything checked except Fast Node Manager, and returns the tokens the
        user leaves checked.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter()]
        [hashtable]$Enabled = @{},

        [Parameter()]
        [string]$Color = '',

        [Parameter()]
        [string]$CodeColor = '#5fd7ff'
    )

    # Section -> ordered features (display label <-> Initialize-PwshProfile token). 'Shell completions'
    # sits under Tools (completions are operations on the tools) and is skipped via -Skip Completions,
    # like the other tools — at runtime it registers as the final sub-step of the Tools section.
    $sections = [ordered]@{
        Shell  = @(
            [pscustomobject]@{ Label = 'PSReadLine config'; Token = 'PSReadLine' }
        )
        Prompt = @(
            [pscustomobject]@{ Label = 'Terminal-Icons'; Token = 'TerminalIcons' }
            [pscustomobject]@{ Label = 'posh-git'; Token = 'PoshGit' }
        )
        Tools  = @(
            [pscustomobject]@{ Label = 'Zoxide (smart cd)'; Token = 'Zoxide' }
            [pscustomobject]@{ Label = 'fzf (fuzzy finder)'; Token = 'Fzf' }
            [pscustomobject]@{ Label = 'Fast Node Manager (fnm)'; Token = 'Fnm' }
            [pscustomobject]@{ Label = 'xh (HTTP client)'; Token = 'Xh' }
            [pscustomobject]@{ Label = 'bat (cat replacement)'; Token = 'Bat' }
            [pscustomobject]@{ Label = 'fd (file finder)'; Token = 'Fd' }
            [pscustomobject]@{ Label = 'Shell completions'; Token = 'Completions' }
        )
    }

    $allFeatures = foreach ($key in $sections.Keys) { $sections[$key] }
    $allTokens = @($allFeatures | ForEach-Object { $_.Token })
    $labelToToken = @{}
    foreach ($f in $allFeatures) { $labelToToken[$f.Label] = $f.Token }

    # A token is checked unless the caller explicitly disabled it.
    $isEnabled = { param($token) -not ($Enabled.ContainsKey($token) -and -not $Enabled[$token]) }

    # Non-interactive / Spectre unavailable: everything enabled.
    if (-not ('Spectre.Console.MultiSelectionPrompt`1' -as [type])) {
        return $allTokens
    }

    # A per-feature legend above the tree, so each checkbox has context (the Spectre tree itself can't
    # carry per-item descriptions). oh-my-posh isn't a checkbox — it always runs — so it's noted here.
    $accent = if ($Color) { $Color } else { '#c9aaff' }
    Write-PwshProfilePromptHelp @(
        '**oh-my-posh** is always enabled — it draws the prompt and has no checkbox.'
        '**PSReadLine** config — nicer command-line editing: history search, syntax colors, prediction.'
        '**Terminal-Icons** — file-type icons in directory listings (`ls` / `Get-ChildItem`).'
        '**posh-git** — git branch and status shown right in the prompt.'
        '**Zoxide** (smart `cd`) — a cd that learns your most-used dirs so you can jump by partial name.'
        '**fzf** (fuzzy finder) — a fast command-line fuzzy picker (full UI style; via PSFzf adds `Ctrl+T` file picker with a `bat` preview, `Ctrl+R` fuzzy history, and `Ctrl+G` git pickers); when on PATH, zoxide uses it for its interactive `cdi`/`zi` jump.'
        '**Fast Node Manager** (`fnm`) — install and switch between Node.js versions per project.'
        '**xh** (HTTP client) — a fast, friendly `curl`/HTTPie-style tool for making HTTP requests.'
        '**bat** (cat replacement) — a `cat` with syntax highlighting and git integration; its theme blends with the prompt. You can replace the built-in `cat` with it.'
        '**fd** (file finder) — a fast, friendly `find` alternative that respects `.gitignore`; its colors blend with the prompt and, with fzf, drive fzf''s file search. Standalone — it does not replace `Get-ChildItem`.'
        '**Shell completions** — Tab completion for `winget`, `tailscale`, `docker`, and `op`.'
    ) -Accent $accent -Code $CodeColor

    $prompt = [Spectre.Console.MultiSelectionPrompt[string]]::new()
    $prompt.Title = 'Select the features to enable (Space toggles a feature or a whole section; Enter submits)'
    $prompt.PageSize = 12
    $prompt.WrapAround = $true
    $prompt.Required = $false
    $prompt.HighlightStyle = [Spectre.Console.Style]::new((Get-SpectreColorValue $accent))

    foreach ($key in $sections.Keys) {
        $labels = @($sections[$key] | ForEach-Object { $_.Label })
        $prompt = [Spectre.Console.MultiSelectionPromptExtensions]::AddChoiceGroup($prompt, $key, [string[]]$labels)
    }

    # Pre-check every currently-enabled feature so the tree opens with the user's state (all on by
    # default on the first pass). A fully-enabled section also gets its header checked — in Leaf mode
    # the parent's box is derived from children only during interaction, not at the initial render, so
    # without this the section shows unchecked while its features show checked. A partially-enabled
    # section is left unselected so it correctly shows as partial.
    foreach ($key in $sections.Keys) {
        $children = @($sections[$key])
        $enabledChildren = @($children | Where-Object { & $isEnabled $_.Token })
        if ($enabledChildren.Count -eq $children.Count) {
            $prompt = [Spectre.Console.MultiSelectionPromptExtensions]::Select($prompt, $key)
        }
        foreach ($c in $enabledChildren) {
            $prompt = [Spectre.Console.MultiSelectionPromptExtensions]::Select($prompt, $c.Label)
        }
    }

    $selectedLabels = @($prompt.Show([Spectre.Console.AnsiConsole]::Console))
    $selectedTokens = @($selectedLabels | ForEach-Object { $labelToToken[$_] } | Where-Object { $_ })

    return $selectedTokens
}
