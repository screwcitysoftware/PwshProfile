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

        PathDir and Scope go with them. Most catalog tools are winget portables landing in the shared
        Links directory — Install-WingetPackageSafe's default — and declare both as $null. The two full
        installers do not: git lands in %ProgramFiles%\Git\cmd (no Scope, so winget's machine default,
        which may need elevation) and oh-my-posh in %LOCALAPPDATA%\Programs\oh-my-posh\bin under user
        scope. They used to sit outside this catalog for exactly that reason; they are in it now so the
        wizard can show the FULL list of what setup puts on the machine, and the columns are what keeps
        Install-PwshProfile from installing them to the wrong place.

        The grouping is DERIVED from the install kind rather than hard-coded by name: the WinGet group
        is exactly the 'winget' entries, everything else is Core. A future feature just declares its
        kind and lands in the right group. Note this groups by install MODEL, not by the startup section
        a feature renders under: git and oh-my-posh are winget packages and group here as WinGet, while
        Initialize-PwshProfile deliberately runs them in its Core section (git first, so it is on PATH
        for posh-git and the git-aware WinGet tools). The `which` alias is the one always-on feature
        still absent — it installs nothing.

        By default returns an ordered map of group name -> feature rows, each carrying Label (a
        human-readable name), Token (the tool's identifier), Install (the kind), PackageId and Exe
        (the winget package and its executable, $null for a non-winget row), PathDir and Scope (the
        install-location overrides, $null to take Install-WingetPackageSafe's defaults), Help (a
        one-line description), and Url (the project's homepage or repo, for the wizard's clickable
        inventory rows; $null only for Completions, which bundles six unrelated CLIs rather than
        naming one project).

    .PARAMETER Token
        Return the flat ordered token list instead — Core features first, then the winget CLIs in
        install order.

    .EXAMPLE
        Get-PwshProfileToolCatalog

        Returns the ordered Core / WinGet group map with its labeled, install-kinded feature rows.

    .EXAMPLE
        Get-PwshProfileToolCatalog -Token

        Returns @('PSReadLine','TerminalIcons','PoshGit','Completions','Git','OhMyPosh','Zoxide','Fzf',
        'Fnm','Xh','Jq','Bat','Fd','Ripgrep','Less','Lazygit','Uv').
    #>
    [CmdletBinding(DefaultParameterSetName = 'Grouped')]
    param(
        [Parameter(ParameterSetName = 'Token')]
        [switch]$Token
    )

    # Flat feature list in display/install order: Core features first, then the WinGet tools with git and
    # oh-my-posh at the head -- git must be on PATH before the tools that shell out to it. A feature's
    # group is DERIVED from its Install kind, so the "WinGet = winget installs" rule can't drift. Only
    # the `which` alias is absent now: it is always-on but installs nothing, so there is nothing to say.
    $entries = @(
        [pscustomobject]@{ Label = 'PSReadLine config'; Token = 'PSReadLine'; Install = 'none'
            PackageId = $null; Exe = $null; PathDir = $null; Scope = $null
            Url = 'https://github.com/PowerShell/PSReadLine'
            Help = '**PSReadLine** config — nicer command-line editing: history search, syntax colors, prediction.' }
        [pscustomobject]@{ Label = 'Terminal-Icons'; Token = 'TerminalIcons'; Install = 'module'
            PackageId = $null; Exe = $null; PathDir = $null; Scope = $null
            Url = 'https://github.com/devblackops/Terminal-Icons'
            Help = '**Terminal-Icons** — file-type icons in directory listings (`ls` / `Get-ChildItem`).' }
        [pscustomobject]@{ Label = 'posh-git'; Token = 'PoshGit'; Install = 'module'
            PackageId = $null; Exe = $null; PathDir = $null; Scope = $null
            Url = 'https://github.com/dahlbyk/posh-git'
            Help = '**posh-git** — git branch and status shown right in the prompt.' }
        [pscustomobject]@{ Label = 'Shell completions'; Token = 'Completions'; Install = 'none'
            PackageId = $null; Exe = $null; PathDir = $null; Scope = $null
            # No single project to link -- this row bundles six unrelated CLIs' own completers.
            Url = $null
            Help = '**Shell completions** — Tab completion for `winget`, `az`, `tailscale`, `docker`, `op`, and `gh`.' }
        [pscustomobject]@{ Label = 'git (version control)'; Token = 'Git'; Install = 'winget'
            PackageId = 'Git.Git'; Exe = 'git.exe'
            PathDir = (Join-Path $env:ProgramFiles 'Git\cmd'); Scope = $null
            Url = 'https://git-scm.com/'
            Help = '**git** — version control, and the foundation **posh-git**, **lazygit**, and fzf''s git pickers all build on. Installed first so it is on PATH for them.' }
        [pscustomobject]@{ Label = 'oh-my-posh (prompt)'; Token = 'OhMyPosh'; Install = 'winget'
            PackageId = 'JanDeDobbeleer.OhMyPosh'; Exe = 'oh-my-posh.exe'
            PathDir = (Join-Path $env:LOCALAPPDATA 'Programs\oh-my-posh\bin'); Scope = 'user'
            Url = 'https://ohmyposh.dev'
            Help = '**oh-my-posh** — the prompt engine that renders the theme you pick, with git status, timings, and OS glyphs.' }
        [pscustomobject]@{ Label = 'zoxide (smart cd)'; Token = 'Zoxide'; Install = 'winget'
            PackageId = 'ajeetdsouza.zoxide'; Exe = 'zoxide.exe'; PathDir = $null; Scope = $null
            Url = 'https://github.com/ajeetdsouza/zoxide'
            Help = '**zoxide** (smart `cd`) — a cd that learns your most-used dirs so you can jump by partial name.' }
        [pscustomobject]@{ Label = 'fzf (fuzzy finder)'; Token = 'Fzf'; Install = 'winget'
            PackageId = 'junegunn.fzf'; Exe = 'fzf.exe'; PathDir = $null; Scope = $null
            Url = 'https://github.com/junegunn/fzf'
            Help = '**fzf** (fuzzy finder) — a fast command-line fuzzy picker (full UI style; via PSFzf adds `Ctrl+T` file picker with a `bat` preview, `Ctrl+R` fuzzy history, and `Ctrl+G` git pickers); when on PATH, zoxide uses it for its interactive `cdi`/`zi` jump.' }
        [pscustomobject]@{ Label = 'fnm (Fast Node Manager)'; Token = 'Fnm'; Install = 'winget'
            PackageId = 'Schniz.fnm'; Exe = 'fnm.exe'; PathDir = $null; Scope = $null
            Url = 'https://github.com/Schniz/fnm'
            Help = '**fnm** (Fast Node Manager) — install and switch between Node.js versions per project.' }
        [pscustomobject]@{ Label = 'xh (HTTP client)'; Token = 'Xh'; Install = 'winget'
            PackageId = 'ducaale.xh'; Exe = 'xh.exe'; PathDir = $null; Scope = $null
            Url = 'https://github.com/ducaale/xh'
            Help = '**xh** (HTTP client) — a fast, friendly `curl`/HTTPie-style tool for making HTTP requests.' }
        [pscustomobject]@{ Label = 'jq (JSON processor)'; Token = 'Jq'; Install = 'winget'
            PackageId = 'jqlang.jq'; Exe = 'jq.exe'; PathDir = $null; Scope = $null
            Url = 'https://github.com/jqlang/jq'
            Help = '**jq** (JSON processor) — a lightweight command-line JSON query and transformation tool.' }
        [pscustomobject]@{ Label = 'bat (cat replacement)'; Token = 'Bat'; Install = 'winget'
            PackageId = 'sharkdp.bat'; Exe = 'bat.exe'; PathDir = $null; Scope = $null
            Url = 'https://github.com/sharkdp/bat'
            Help = '**bat** (cat replacement) — a `cat` with syntax highlighting and git integration; its theme blends with the prompt. You can replace the built-in `cat` with it.' }
        [pscustomobject]@{ Label = 'fd (file finder)'; Token = 'Fd'; Install = 'winget'
            PackageId = 'sharkdp.fd'; Exe = 'fd.exe'; PathDir = $null; Scope = $null
            Url = 'https://github.com/sharkdp/fd'
            Help = '**fd** (file finder) — a fast, friendly `find` alternative that respects `.gitignore`; its colors blend with the prompt and, with fzf, drive fzf''s file search. Standalone — it does not replace `Get-ChildItem`.' }
        [pscustomobject]@{ Label = 'ripgrep (fast grep)'; Token = 'Ripgrep'; Install = 'winget'
            PackageId = 'BurntSushi.ripgrep.MSVC'; Exe = 'rg.exe'; PathDir = $null; Scope = $null
            Url = 'https://github.com/BurntSushi/ripgrep'
            Help = '**ripgrep** (fast grep) — a very fast recursive search of file *contents* that respects `.gitignore` — the content-search counterpart to fd. Standalone — it does not replace `Select-String`.' }
        [pscustomobject]@{ Label = 'less (pager)'; Token = 'Less'; Install = 'winget'
            PackageId = 'jftuga.less'; Exe = 'less.exe'; PathDir = $null; Scope = $null
            # GNU's own page, not the jftuga/less-Windows repackaging winget actually installs -- the
            # GNU page is the authoritative usage docs, which is the point of linking at all.
            Url = 'https://www.gnu.org/software/less/'
            Help = '**less** (pager) — a full-featured pager (color, search, backward scroll) that replaces the limited `more.com`; it is what lets `bat` page with color. You can route `help`/`more` and color CLIs through it.' }
        [pscustomobject]@{ Label = 'lazygit (git TUI)'; Token = 'Lazygit'; Install = 'winget'
            PackageId = 'JesseDuffield.lazygit'; Exe = 'lazygit.exe'; PathDir = $null; Scope = $null
            Url = 'https://github.com/jesseduffield/lazygit'
            Help = '**lazygit** (git TUI) — a full-screen terminal UI for git: stage hunks, branch, rebase, and stash without leaving the shell.' }
        [pscustomobject]@{ Label = 'uv (Python toolchain)'; Token = 'Uv'; Install = 'winget'
            PackageId = 'astral-sh.uv'; Exe = 'uv.exe'; PathDir = $null; Scope = $null
            Url = 'https://github.com/astral-sh/uv'
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
