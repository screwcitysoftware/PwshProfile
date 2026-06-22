function Install-WingetPackageSafe {
    <#
    .SYNOPSIS
        Installs a winget package once per session and patches PATH so the exe is usable immediately.

    .DESCRIPTION
        The shared Install half of the Enable-* tool-enabler pattern. It is a no-op when the
        package's exe is already on PATH; otherwise it installs the package via Microsoft's
        first-party Microsoft.WinGet.Client module (Install-WinGetPackage, loaded on demand through
        Import-ModuleSafe), then patches the *current session's* $env:Path with the directory the
        package lands in (winget only updates the registry user PATH), and finally re-checks for the
        exe. If the exe still isn't resolvable, it emits a Write-Warning that includes the install
        result Status.

        The already-installed short-circuit runs *before* the module is loaded, so once a tool is
        present, profile startup never imports Microsoft.WinGet.Client — only a first-time (or
        missing) install pays that cost.

        Success is judged by the post-install Get-Command re-check (ground truth), with the result's
        Status surfaced in the warning for diagnostics. Nothing here throws, so profile startup
        continues even when an install fails.

    .PARAMETER Id
        The winget package id to install (passed as -Id), e.g. 'ajeetdsouza.zoxide'.

    .PARAMETER Exe
        The executable name to probe with Get-Command, e.g. 'zoxide.exe'. Both the
        already-installed short-circuit and the post-install success check key off this.

    .PARAMETER PathDir
        The directory the package's exe lands in, appended to this session's $env:Path if not
        already present. Optional: when omitted it defaults to the winget portable Links directory
        ($env:LOCALAPPDATA\Microsoft\WinGet\Links), which the portable enablers (bat, xh, jq, fzf,
        fd, zoxide, fnm) all share. Installer packages (e.g. oh-my-posh) pass their own program dir.
        The default is resolved only after the already-installed short-circuit, so a present tool
        never builds the path.

    .PARAMETER Scope
        Optional install scope: 'user' or 'machine'. Maps to Install-WinGetPackage's -Scope
        (User / System). Omit to let winget choose (its own default).

    .PARAMETER CallerName
        The enabler function's name, used to prefix the diagnostic warning so the failing tool is
        identifiable (e.g. 'Enable-Zoxide').

    .EXAMPLE
        Install-WingetPackageSafe -Id 'ajeetdsouza.zoxide' -Exe 'zoxide.exe' -CallerName 'Enable-Zoxide'

        A winget portable: -PathDir is omitted, so it defaults to the WinGet\Links directory.

    .EXAMPLE
        Install-WingetPackageSafe -Id 'JanDeDobbeleer.OhMyPosh' -Exe 'oh-my-posh.exe' `
            -PathDir (Join-Path $env:LOCALAPPDATA 'Programs\oh-my-posh\bin') `
            -Scope user -CallerName 'Enable-OhMyPosh'

    .NOTES
        Call this from inside an Invoke-Step "Install" { } block in an Enable-* function; the
        matching Initialize step (guarded by Get-Command <exe>) degrades gracefully if the install
        didn't take.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Id,

        [Parameter(Mandatory, Position = 1)]
        [string]$Exe,

        [Parameter(Position = 2)]
        [string]$PathDir,

        [Parameter()]
        [ValidateSet('user', 'machine')]
        [string]$Scope,

        [Parameter(Mandatory)]
        [string]$CallerName
    )

    # Short-circuit BEFORE loading the module: an already-installed tool costs nothing at startup.
    if (Get-Command $Exe -ErrorAction SilentlyContinue) { return }

    # Resolve the default Links dir only after the short-circuit, so a present tool never builds it.
    # Most enablers install winget portables, which all land in this shared directory.
    if ([string]::IsNullOrEmpty($PathDir)) {
        $PathDir = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'
    }

    Import-ModuleSafe Microsoft.WinGet.Client
    if (-not (Get-Command Install-WinGetPackage -ErrorAction SilentlyContinue)) {
        Write-Warning "${CallerName}: Microsoft.WinGet.Client is unavailable; cannot install $Id."
        return
    }

    $installArgs = @{ Id = $Id; Source = 'winget'; MatchOption = 'Equals'; Mode = 'Silent' }
    if ($PSBoundParameters.ContainsKey('Scope')) {
        $installArgs.Scope = if ($Scope -eq 'machine') { 'System' } else { 'User' }
    }

    # Suppress the cmdlet's progress so it doesn't tear Invoke-Step's live Spectre spinner.
    $result = $null
    $prevProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        $result = Install-WinGetPackage @installArgs
    }
    catch {
        Write-Warning "${CallerName}: Install-WinGetPackage of $Id threw: $($_.Exception.Message)"
    }
    finally {
        $ProgressPreference = $prevProgress
    }

    # winget only updates the *user* PATH (registry) — patch this session's PATH so the Initialize
    # substep can resolve the exe immediately.
    # Split on ';' and compare exactly (case-insensitive -notcontains) so $PathDir is matched
    # literally — avoids -like treating any '[' / '*' in the path as a wildcard pattern.
    if (($env:Path -split ';') -notcontains $PathDir) {
        $env:Path += ";$PathDir"
    }

    # Ground truth beats the result code: if the exe still isn't resolvable, it didn't take.
    if (-not (Get-Command $Exe -ErrorAction SilentlyContinue)) {
        Write-Warning "${CallerName}: install of $Id did not produce $Exe on PATH. Status=$($result.Status) ErrorCode=$($result.InstallerErrorCode)"
    }
}
