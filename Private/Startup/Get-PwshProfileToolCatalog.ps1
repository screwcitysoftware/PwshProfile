function Get-PwshProfileToolCatalog {
    <#
    .SYNOPSIS
        Returns the catalog of opt-in startup features — grouped Core / WinGet — as the single source
        of truth for the tool set, its install kinds, and the clean-install defaults.

    .DESCRIPTION
        The one place the toggleable startup features are defined, so the wizard's feature tree
        (Read-PwshProfileFeatureTree), the wizard's seeding/defaults (Invoke-PwshProfileWizard), the
        orchestrator's section rendering (Initialize-PwshProfile), and the opt-in resolution / new-tool
        detection all agree on the same list. The set is also mirrored by the [ValidateSet] on
        Initialize-PwshProfile's -Enable parameter, and a test (Tests/ToolCatalog.Tests.ps1) asserts
        that literal stays in sync with this catalog.

        Each feature carries an Install kind:
          winget — installed as a CLI binary via Install-WingetPackageSafe.
          module — installed as a PowerShell Gallery module via Import-ModuleSafe.
          none   — no install (built-in config, or registration that detects an external tool).

        The grouping rule is derived from that kind, not hard-coded by name: the **WinGet** group is
        exactly the entries with Install 'winget'; everything else is **Core**. So a future feature that
        doesn't fit just declares its kind and lands in the right group with no rework. oh-my-posh and
        the `which` alias are deliberately absent — they are always-on (not opt-in tokens).

        By default returns an ordered hashtable of group name (Core, then WinGet) -> array of
        [pscustomobject] feature rows, each with:
          Label   — the human-readable label shown in the wizard's feature tree.
          Token   — the Initialize-PwshProfile -Enable token.
          Install — the install kind ('winget' | 'module' | 'none').

        With -Token, returns the flat, ordered token list (Core tokens first, then WinGet) — the order
        -Enable lists them and the ValidateSet declares them.

        With -DefaultEnabled, returns the tokens that should be checked on a clean (first-run) install:
        everything that is NOT a winget install (Install -ne 'winget'). This centralizes the
        "Core checked, WinGet unchecked by default" rule.

    .PARAMETER Token
        Return the flat ordered token list (string[]) rather than the grouped structure.

    .PARAMETER DefaultEnabled
        Return the clean-install default-on token list (string[]) — the non-winget tokens. Mutually
        exclusive with -Token.

    .EXAMPLE
        Get-PwshProfileToolCatalog

        Returns the ordered Core / WinGet group map with its labeled, install-kinded feature rows.

    .EXAMPLE
        Get-PwshProfileToolCatalog -Token

        Returns @('PSReadLine','TerminalIcons','PoshGit','Completions','Zoxide','Fzf','Fnm','Xh','Jq','Bat','Fd','Less','Lazygit').

    .EXAMPLE
        Get-PwshProfileToolCatalog -DefaultEnabled

        Returns @('PSReadLine','TerminalIcons','PoshGit','Completions') — the non-winget tokens checked
        by default on a clean install.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Grouped')]
    param(
        [Parameter(ParameterSetName = 'Token')]
        [switch]$Token,

        [Parameter(ParameterSetName = 'DefaultEnabled')]
        [switch]$DefaultEnabled
    )

    # Flat feature list in display/run order: the Core features first, then the WinGet tools (their
    # order mirrors the orchestrator's run order: zoxide, fzf, fnm, xh, jq, bat, fd, less, lazygit). The group a
    # feature belongs to is DERIVED from its Install kind, so the "WinGet = winget installs" rule can't
    # drift. oh-my-posh and the `which` alias are intentionally absent (always-on, not tokens).
    $entries = @(
        [pscustomobject]@{ Label = 'PSReadLine config'; Token = 'PSReadLine'; Install = 'none' }
        [pscustomobject]@{ Label = 'Terminal-Icons'; Token = 'TerminalIcons'; Install = 'module' }
        [pscustomobject]@{ Label = 'posh-git'; Token = 'PoshGit'; Install = 'module' }
        [pscustomobject]@{ Label = 'Shell completions'; Token = 'Completions'; Install = 'none' }
        [pscustomobject]@{ Label = 'zoxide (smart cd)'; Token = 'Zoxide'; Install = 'winget' }
        [pscustomobject]@{ Label = 'fzf (fuzzy finder)'; Token = 'Fzf'; Install = 'winget' }
        [pscustomobject]@{ Label = 'fnm (Fast Node Manager)'; Token = 'Fnm'; Install = 'winget' }
        [pscustomobject]@{ Label = 'xh (HTTP client)'; Token = 'Xh'; Install = 'winget' }
        [pscustomobject]@{ Label = 'jq (JSON processor)'; Token = 'Jq'; Install = 'winget' }
        [pscustomobject]@{ Label = 'bat (cat replacement)'; Token = 'Bat'; Install = 'winget' }
        [pscustomobject]@{ Label = 'fd (file finder)'; Token = 'Fd'; Install = 'winget' }
        [pscustomobject]@{ Label = 'less (pager)'; Token = 'Less'; Install = 'winget' }
        [pscustomobject]@{ Label = 'lazygit (git TUI)'; Token = 'Lazygit'; Install = 'winget' }
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
