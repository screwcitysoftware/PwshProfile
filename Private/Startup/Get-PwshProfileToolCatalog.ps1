function Get-PwshProfileToolCatalog {
    <#
    .SYNOPSIS
        Returns the catalog of opt-in startup features — grouped Core / WinGet — as the single source of
        truth for the tool set, its install kinds, and the clean-install defaults.

    .DESCRIPTION
        The one place the toggleable startup features are defined, so the wizard's feature tree, the
        wizard's seeding, the orchestrator's section rendering, and the opt-in resolution all agree.
        Initialize-PwshProfile's -Enable [ValidateSet] mirrors this list, and Tests/ToolCatalog.Tests.ps1
        asserts the literal stays in sync.

        Each feature carries an Install kind:
          winget — installed as a CLI binary via Install-WingetPackageSafe.
          module — installed as a PowerShell Gallery module via Import-ModuleSafe.
          none   — no install (built-in config, or registration that detects an external tool).

        The grouping is DERIVED from that kind rather than hard-coded by name: the WinGet group is
        exactly the 'winget' entries, everything else is Core. A future feature just declares its kind
        and lands in the right group. oh-my-posh, git and the `which` alias are deliberately absent —
        they are always-on, not opt-in tokens.

        By default returns an ordered map of group name -> feature rows, each carrying Label (shown in
        the wizard tree), Token (the -Enable token), and Install (the kind).

    .PARAMETER Token
        Return the flat ordered token list instead — the order -Enable lists them and the ValidateSet
        declares them.

    .PARAMETER DefaultEnabled
        Return the tokens checked on a clean first-run install: everything that is not a winget
        install. This centralizes the "Core checked, WinGet unchecked" rule. Mutually exclusive
        with -Token.

    .EXAMPLE
        Get-PwshProfileToolCatalog

        Returns the ordered Core / WinGet group map with its labeled, install-kinded feature rows.

    .EXAMPLE
        Get-PwshProfileToolCatalog -Token

        Returns @('PSReadLine','TerminalIcons','PoshGit','Completions','Zoxide','Fzf','Fnm','Xh','Jq','Bat','Fd','Less','Lazygit').

    .EXAMPLE
        Get-PwshProfileToolCatalog -DefaultEnabled

        Returns @('PSReadLine','TerminalIcons','PoshGit','Completions') — the non-winget tokens.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Grouped')]
    param(
        [Parameter(ParameterSetName = 'Token')]
        [switch]$Token,

        [Parameter(ParameterSetName = 'DefaultEnabled')]
        [switch]$DefaultEnabled
    )

    # Flat feature list in display/run order: Core first, then the WinGet tools in the orchestrator's
    # run order. A feature's group is DERIVED from its Install kind, so the "WinGet = winget installs"
    # rule can't drift. oh-my-posh, git and the `which` alias are absent (always-on, not tokens).
    $entries = @(
        [pscustomobject]@{ Label = 'PSReadLine config'; Token = 'PSReadLine'; Install = 'none'
            Help = '**PSReadLine** config — nicer command-line editing: history search, syntax colors, prediction.' }
        [pscustomobject]@{ Label = 'Terminal-Icons'; Token = 'TerminalIcons'; Install = 'module'
            Help = '**Terminal-Icons** — file-type icons in directory listings (`ls` / `Get-ChildItem`).' }
        [pscustomobject]@{ Label = 'posh-git'; Token = 'PoshGit'; Install = 'module'
            Help = '**posh-git** — git branch and status shown right in the prompt.' }
        [pscustomobject]@{ Label = 'Shell completions'; Token = 'Completions'; Install = 'none'
            Help = '**Shell completions** — Tab completion for `winget`, `az`, `tailscale`, `docker`, `op`, and `gh`.' }
        [pscustomobject]@{ Label = 'zoxide (smart cd)'; Token = 'Zoxide'; Install = 'winget'
            Help = '**zoxide** (smart `cd`) — a cd that learns your most-used dirs so you can jump by partial name.' }
        [pscustomobject]@{ Label = 'fzf (fuzzy finder)'; Token = 'Fzf'; Install = 'winget'
            Help = '**fzf** (fuzzy finder) — a fast command-line fuzzy picker (full UI style; via PSFzf adds `Ctrl+T` file picker with a `bat` preview, `Ctrl+R` fuzzy history, and `Ctrl+G` git pickers); when on PATH, zoxide uses it for its interactive `cdi`/`zi` jump.' }
        [pscustomobject]@{ Label = 'fnm (Fast Node Manager)'; Token = 'Fnm'; Install = 'winget'
            Help = '**fnm** (Fast Node Manager) — install and switch between Node.js versions per project.' }
        [pscustomobject]@{ Label = 'xh (HTTP client)'; Token = 'Xh'; Install = 'winget'
            Help = '**xh** (HTTP client) — a fast, friendly `curl`/HTTPie-style tool for making HTTP requests.' }
        [pscustomobject]@{ Label = 'jq (JSON processor)'; Token = 'Jq'; Install = 'winget'
            Help = '**jq** (JSON processor) — a lightweight command-line JSON query and transformation tool.' }
        [pscustomobject]@{ Label = 'bat (cat replacement)'; Token = 'Bat'; Install = 'winget'
            Help = '**bat** (cat replacement) — a `cat` with syntax highlighting and git integration; its theme blends with the prompt. You can replace the built-in `cat` with it.' }
        [pscustomobject]@{ Label = 'fd (file finder)'; Token = 'Fd'; Install = 'winget'
            Help = '**fd** (file finder) — a fast, friendly `find` alternative that respects `.gitignore`; its colors blend with the prompt and, with fzf, drive fzf''s file search. Standalone — it does not replace `Get-ChildItem`.' }
        [pscustomobject]@{ Label = 'less (pager)'; Token = 'Less'; Install = 'winget'
            Help = '**less** (pager) — a full-featured pager (color, search, backward scroll) that replaces the limited `more.com`; it is what lets `bat` page with color. You can route `help`/`more` and color CLIs through it.' }
        [pscustomobject]@{ Label = 'lazygit (git TUI)'; Token = 'Lazygit'; Install = 'winget'
            Help = '**lazygit** (git TUI) — a full-screen terminal UI for git: stage hunks, branch, rebase, and stash without leaving the shell.' }
    )

    if ($Token) {
        return @($entries.Token)
    }
    if ($DefaultEnabled) {
        return @(($entries | Where-Object { $_.Install -ne 'winget' }).Token)
    }

    # Group: WinGet = winget installs, Core = everything else (preserving entry order within each).
    [ordered]@{
        Core   = @($entries | Where-Object { $_.Install -ne 'winget' })
        WinGet = @($entries | Where-Object { $_.Install -eq 'winget' })
    }
}
