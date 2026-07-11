function Read-PwshProfileFeatureTree {
    <#
    .SYNOPSIS
        Prompts the user with a grouped, opt-in feature tree and returns the tokens the user checked.

    .DESCRIPTION
        Drives the Install-PwshProfile wizard's feature step. The features come from
        Get-PwshProfileToolCatalog and are grouped under two sections — Core and WinGet — so the user
        can toggle an individual feature or a whole section at once. The shell completions live under
        Core. This function is purely seed-driven: a feature starts CHECKED only when -Enabled marks it
        (so an empty map opens with everything unchecked), and the wizard maps the checked set to
        -Enable. The caller decides the seed — a re-run passes the prior -Enable set, a clean first run
        passes the Core default-on set (Get-PwshProfileToolCatalog -DefaultEnabled), so Core opens
        checked and WinGet unchecked.

        oh-my-posh is deliberately absent from the tree: it always runs, so listing it would be a
        checkbox that does nothing. Above the prompt a grey legend (Write-PwshProfilePromptHelp)
        describes each feature in one line — including the note that oh-my-posh is always enabled — since
        the Spectre tree can't carry per-item descriptions. Tools in -New are tagged "(new)" with a
        legend note so additions since the prior setup stand out.

        The grouped multi-selection is built directly on the Spectre.Console MultiSelectionPrompt
        API rather than Read-SpectreMultiSelectionGrouped, because that wrapper cannot pre-check
        items. The prompt's string values are the (possibly "(new)"-tagged) feature labels; this
        function maps the returned labels back to their tokens.

        If the Spectre prompt types are unavailable (non-interactive host), it degrades by returning
        just the tokens marked enabled in -Enabled (whatever the caller seeded), matching the module's
        non-interactive fallback elsewhere.

    .PARAMETER Enabled
        A hashtable mapping each feature token (from Get-PwshProfileToolCatalog) to a boolean for its
        initial checked state. Selection is seed-driven: a token is checked ONLY when its value is $true,
        so an empty map opens with everything unchecked. The caller supplies the seed — a re-run passes
        the prior -Enable set, a clean first run passes the Core default-on set (Core checked, WinGet
        unchecked).

    .PARAMETER New
        Tokens that are newly available since the prior setup (current catalog minus the recorded
        snapshot). Their labels are tagged "(new)" and a legend note calls them out; they still start
        unchecked (per the opt-in rule) so the user consciously adopts them.

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
        [string[]]$New = @(),

        [Parameter()]
        [string]$Color,

        [Parameter()]
        [string]$CodeColor = '#5fd7ff'
    )

    # Section -> ordered features (label <-> -Enable token) from the single-source catalog. Tag tokens
    # in -New with a "(new)" suffix so additions since the prior setup stand out; the catalog returns
    # fresh objects each call, so mutating the labels here is safe.
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

    # Non-interactive / Spectre unavailable: return only the tokens already marked enabled (nothing on
    # a first run), matching the opt-in model rather than turning everything on.
    if (-not ('Spectre.Console.MultiSelectionPrompt`1' -as [type])) {
        return @($allTokens | Where-Object { & $isEnabled $_ })
    }

    # A per-feature legend above the tree, so each checkbox has context (the Spectre tree itself can't
    # carry per-item descriptions). oh-my-posh isn't a checkbox — it always runs — so it's noted here.
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

    # Pre-check every currently-enabled feature so the tree opens with the seeded state (Core on,
    # WinGet off on a clean first run). A fully-enabled section also gets its header checked — in Leaf mode
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
