function Get-PwshProfileToolCatalog {
    <#
    .SYNOPSIS
        Returns the catalog of startup features — grouped Core / WinGet — as the single source of
        truth for the tool set and its install kinds.

    .DESCRIPTION
        The one place the startup features are defined, so everything that needs to enumerate the
        tool set agrees on it. Every tool runs at startup; this catalog is what says which ones are
        winget CLIs (and so what setup has to install) versus PowerShell modules or plain config.

        Each feature carries an Install kind:
          winget — installed as a CLI binary via Install-WingetPackageSafe.
          module — installed as a PowerShell Gallery module via Import-ModuleSafe.
          none   — no install (built-in config, or registration that detects an external tool).

        A 'winget' row also carries PackageId and Exe — the same two values its Enable-* function
        passes to Install-WingetPackageSafe. That is what lets Install-PwshProfile install the whole
        set up front without calling the enablers, which would also *wire* the setup session (aliasing
        cat mid-wizard, say). Both must agree with the enabler, and Tests/ToolCatalog.Tests.ps1 reads
        the enabler sources to prove they do. Every row declares them even where they are $null: the
        suite runs under Set-StrictMode -Version Latest, where reading a property a row omitted throws
        rather than returning $null.

        No PathDir/Scope columns: every catalog tool is a winget portable landing in the shared Links
        directory, which is Install-WingetPackageSafe's default. The two packages that need their own
        (git, oh-my-posh) are always-on and outside this catalog.

        The grouping is DERIVED from that kind rather than hard-coded by name: the WinGet group is
        exactly the 'winget' entries, everything else is Core. A future feature just declares its kind
        and lands in the right group. oh-my-posh, git and the `which` alias are deliberately absent —
        they are always-on and not part of this catalog.

        By default returns an ordered map of group name -> feature rows, each carrying Label (a
        human-readable name), Token (the tool's identifier), Install (the kind), PackageId and Exe
        (the winget package and its executable, $null for a non-winget row), and Help (a one-line
        description).

    .PARAMETER Token
        Return the flat ordered token list instead — the tools in the order the orchestrator runs
        them.

    .EXAMPLE
        Get-PwshProfileToolCatalog

        Returns the ordered Core / WinGet group map with its labeled, install-kinded feature rows.

    .EXAMPLE
        Get-PwshProfileToolCatalog -Token

        Returns @('PSReadLine','TerminalIcons','PoshGit','Completions','Zoxide','Fzf','Fnm','Xh','Jq','Bat','Fd','Ripgrep','Less','Lazygit','Uv').
    #>
    [CmdletBinding(DefaultParameterSetName = 'Grouped')]
    param(
        [Parameter(ParameterSetName = 'Token')]
        [switch]$Token
    )

    # Flat feature list in display/run order: Core first, then the WinGet tools in the orchestrator's
    # run order. A feature's group is DERIVED from its Install kind, so the "WinGet = winget installs"
    # rule can't drift. oh-my-posh, git and the `which` alias are absent (always-on, outside this catalog).
    $entries = @(
        [pscustomobject]@{ Label = 'PSReadLine config'; Token = 'PSReadLine'; Install = 'none'
            PackageId = $null; Exe = $null
            Help = '**PSReadLine** config — nicer command-line editing: history search, syntax colors, prediction.' }
        [pscustomobject]@{ Label = 'Terminal-Icons'; Token = 'TerminalIcons'; Install = 'module'
            PackageId = $null; Exe = $null
            Help = '**Terminal-Icons** — file-type icons in directory listings (`ls` / `Get-ChildItem`).' }
        [pscustomobject]@{ Label = 'posh-git'; Token = 'PoshGit'; Install = 'module'
            PackageId = $null; Exe = $null
            Help = '**posh-git** — git branch and status shown right in the prompt.' }
        [pscustomobject]@{ Label = 'Shell completions'; Token = 'Completions'; Install = 'none'
            PackageId = $null; Exe = $null
            Help = '**Shell completions** — Tab completion for `winget`, `az`, `tailscale`, `docker`, `op`, and `gh`.' }
        [pscustomobject]@{ Label = 'zoxide (smart cd)'; Token = 'Zoxide'; Install = 'winget'
            PackageId = 'ajeetdsouza.zoxide'; Exe = 'zoxide.exe'
            Help = '**zoxide** (smart `cd`) — a cd that learns your most-used dirs so you can jump by partial name.' }
        [pscustomobject]@{ Label = 'fzf (fuzzy finder)'; Token = 'Fzf'; Install = 'winget'
            PackageId = 'junegunn.fzf'; Exe = 'fzf.exe'
            Help = '**fzf** (fuzzy finder) — a fast command-line fuzzy picker (full UI style; via PSFzf adds `Ctrl+T` file picker with a `bat` preview, `Ctrl+R` fuzzy history, and `Ctrl+G` git pickers); when on PATH, zoxide uses it for its interactive `cdi`/`zi` jump.' }
        [pscustomobject]@{ Label = 'fnm (Fast Node Manager)'; Token = 'Fnm'; Install = 'winget'
            PackageId = 'Schniz.fnm'; Exe = 'fnm.exe'
            Help = '**fnm** (Fast Node Manager) — install and switch between Node.js versions per project.' }
        [pscustomobject]@{ Label = 'xh (HTTP client)'; Token = 'Xh'; Install = 'winget'
            PackageId = 'ducaale.xh'; Exe = 'xh.exe'
            Help = '**xh** (HTTP client) — a fast, friendly `curl`/HTTPie-style tool for making HTTP requests.' }
        [pscustomobject]@{ Label = 'jq (JSON processor)'; Token = 'Jq'; Install = 'winget'
            PackageId = 'jqlang.jq'; Exe = 'jq.exe'
            Help = '**jq** (JSON processor) — a lightweight command-line JSON query and transformation tool.' }
        [pscustomobject]@{ Label = 'bat (cat replacement)'; Token = 'Bat'; Install = 'winget'
            PackageId = 'sharkdp.bat'; Exe = 'bat.exe'
            Help = '**bat** (cat replacement) — a `cat` with syntax highlighting and git integration; its theme blends with the prompt. You can replace the built-in `cat` with it.' }
        [pscustomobject]@{ Label = 'fd (file finder)'; Token = 'Fd'; Install = 'winget'
            PackageId = 'sharkdp.fd'; Exe = 'fd.exe'
            Help = '**fd** (file finder) — a fast, friendly `find` alternative that respects `.gitignore`; its colors blend with the prompt and, with fzf, drive fzf''s file search. Standalone — it does not replace `Get-ChildItem`.' }
        [pscustomobject]@{ Label = 'ripgrep (fast grep)'; Token = 'Ripgrep'; Install = 'winget'
            PackageId = 'BurntSushi.ripgrep.MSVC'; Exe = 'rg.exe'
            Help = '**ripgrep** (fast grep) — a very fast recursive search of file *contents* that respects `.gitignore` — the content-search counterpart to fd. Standalone — it does not replace `Select-String`.' }
        [pscustomobject]@{ Label = 'less (pager)'; Token = 'Less'; Install = 'winget'
            PackageId = 'jftuga.less'; Exe = 'less.exe'
            Help = '**less** (pager) — a full-featured pager (color, search, backward scroll) that replaces the limited `more.com`; it is what lets `bat` page with color. You can route `help`/`more` and color CLIs through it.' }
        [pscustomobject]@{ Label = 'lazygit (git TUI)'; Token = 'Lazygit'; Install = 'winget'
            PackageId = 'JesseDuffield.lazygit'; Exe = 'lazygit.exe'
            Help = '**lazygit** (git TUI) — a full-screen terminal UI for git: stage hunks, branch, rebase, and stash without leaving the shell.' }
        [pscustomobject]@{ Label = 'uv (Python toolchain)'; Token = 'Uv'; Install = 'winget'
            PackageId = 'astral-sh.uv'; Exe = 'uv.exe'
            Help = '**uv** (Python toolchain) — one fast binary for Python packages, virtualenvs, and interpreters; `uvx` runs a tool without installing it.' }
    )

    if ($Token) {
        return @($entries.Token)
    }

    # Group: WinGet = winget installs, Core = everything else (preserving entry order within each).
    [ordered]@{
        Core   = @($entries | Where-Object { $_.Install -ne 'winget' })
        WinGet = @($entries | Where-Object { $_.Install -eq 'winget' })
    }
}
