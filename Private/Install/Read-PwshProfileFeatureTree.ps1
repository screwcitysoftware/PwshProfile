function Read-PwshProfileFeatureTree {
    <#
    .SYNOPSIS
        Prompts the user with a grouped, opt-in feature tree and returns the tokens the user checked.

    .DESCRIPTION
        Drives the Install-PwshProfile wizard's feature step. The features come from
        Get-PwshProfileToolCatalog, grouped under Core and WinGet so a whole section can be toggled at
        once.

        Selection is purely seed-driven: a feature starts checked only when -Enabled marks it, so an
        empty map opens with everything unchecked. The caller owns the seed — a re-run passes the prior
        -Enable set, a clean first run passes the Core default-on set.

        oh-my-posh is deliberately absent: it always runs, so a checkbox for it would do nothing.
        A grey legend above the prompt describes each feature in one line (and notes that oh-my-posh is
        always enabled), since a Spectre tree can't carry per-item descriptions.

        The prompt is built directly on the Spectre.Console MultiSelectionPrompt API rather than
        Read-SpectreMultiSelectionGrouped, because that wrapper cannot pre-check items. Its values are
        the (possibly "(new)"-tagged) labels, which this function maps back to tokens. Without the
        Spectre types it degrades to returning whatever -Enabled marked, matching the module's
        non-interactive fallback elsewhere.

    .PARAMETER Enabled
        Maps each feature token to its initial checked state. A token is checked ONLY when its value is
        $true, so an empty map opens with everything unchecked.

    .PARAMETER New
        Tokens newly available since the prior setup. Their labels are tagged "(new)" and a legend note
        calls them out, but they still start unchecked so the user consciously adopts them.

    .PARAMETER Color
        Accent color for the prompt highlight and the tool-name spans in the legend — a hex value or a
        Spectre color name.

    .PARAMETER CodeColor
        Color for `code literal` spans in the legend. Defaults to a soft cyan (#5fd7ff).

    .EXAMPLE
        Read-PwshProfileFeatureTree -Enabled @{ PSReadLine = $true; Fnm = $false } -Color '#c9aaff'

        Opens the tree with PSReadLine checked and fnm unchecked, and returns what the user leaves
        checked.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter()]
        [hashtable]$Enabled = @{},

        [Parameter()]
        [string[]]$New = @(),

        [Parameter()]
        [string]$Color,

        [Parameter()]
        [string]$CodeColor = '#5fd7ff'
    )

    # Section -> ordered features (label <-> -Enable token) from the catalog. Tokens in -New get a
    # "(new)" suffix; the catalog returns fresh objects each call, so mutating labels here is safe.
    $sections = Get-PwshProfileToolCatalog
    $newSet = @($New)
    foreach ($key in $sections.Keys) {
        foreach ($f in $sections[$key]) {
            if ($newSet -contains $f.Token) { $f.Label = "$($f.Label) (new)" }
        }
    }

    $allFeatures = foreach ($key in $sections.Keys) { $sections[$key] }
    $allTokens = @($allFeatures | ForEach-Object { $_.Token })
    $labelToToken = @{}
    foreach ($f in $allFeatures) { $labelToToken[$f.Label] = $f.Token }

    # Opt-in: a token is checked only when the caller marked it enabled.
    $isEnabled = { param($token) [bool]($Enabled.ContainsKey($token) -and $Enabled[$token]) }

    # Non-interactive: return only the already-enabled tokens, matching the opt-in model.
    if (-not ('Spectre.Console.MultiSelectionPrompt`1' -as [type])) {
        return @($allTokens | Where-Object { & $isEnabled $_ })
    }

    # Per-feature legend above the tree — Spectre trees can't carry per-item descriptions. oh-my-posh
    # isn't a checkbox (it always runs), so it's noted here instead.
    $accent = if ($Color) { $Color } else { '#c9aaff' }
    $legend = @(
        '**oh-my-posh** is always enabled — it draws the prompt and has no checkbox.'
        '**Core** features are checked by default; the **WinGet** group is unchecked — checking one installs that tool via `winget`.'
        '**PSReadLine** config — nicer command-line editing: history search, syntax colors, prediction.'
        '**Terminal-Icons** — file-type icons in directory listings (`ls` / `Get-ChildItem`).'
        '**posh-git** — git branch and status shown right in the prompt.'
        '**zoxide** (smart `cd`) — a cd that learns your most-used dirs so you can jump by partial name.'
        '**fzf** (fuzzy finder) — a fast command-line fuzzy picker (full UI style; via PSFzf adds `Ctrl+T` file picker with a `bat` preview, `Ctrl+R` fuzzy history, and `Ctrl+G` git pickers); when on PATH, zoxide uses it for its interactive `cdi`/`zi` jump.'
        '**fnm** (Fast Node Manager) — install and switch between Node.js versions per project.'
        '**xh** (HTTP client) — a fast, friendly `curl`/HTTPie-style tool for making HTTP requests.'
        '**jq** (JSON processor) — a lightweight command-line JSON query and transformation tool.'
        '**bat** (cat replacement) — a `cat` with syntax highlighting and git integration; its theme blends with the prompt. You can replace the built-in `cat` with it.'
        '**fd** (file finder) — a fast, friendly `find` alternative that respects `.gitignore`; its colors blend with the prompt and, with fzf, drive fzf''s file search. Standalone — it does not replace `Get-ChildItem`.'
        '**less** (pager) — a full-featured pager (color, search, backward scroll) that replaces the limited `more.com`; it is what lets `bat` page with color. You can route `help`/`more` and color CLIs through it.'
        '**Shell completions** — Tab completion for `winget`, `tailscale`, `docker`, and `op`.'
    )
    if ($newSet.Count) {
        $legend += 'Items tagged **(new)** were added to the module since your last setup — they start unchecked.'
    }
    Write-PwshProfilePromptHelp $legend -Accent $accent -Code $CodeColor

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

    # Pre-check every enabled feature so the tree opens seeded. A fully-enabled section also needs its
    # header checked: in Leaf mode the parent box is derived from children only during interaction, not
    # at first render. A partially-enabled section is left alone so it correctly shows as partial.
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
