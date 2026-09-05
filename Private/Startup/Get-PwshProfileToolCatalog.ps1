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
