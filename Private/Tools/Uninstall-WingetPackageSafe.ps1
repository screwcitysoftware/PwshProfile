function Uninstall-WingetPackageSafe {
    <#
    .SYNOPSIS
        Uninstalls a winget package, the inverse of Install-WingetPackageSafe.

    .DESCRIPTION
        A one-shot user action (called from Uninstall-PwshProfile's removal checkbox), not a startup
        hot path, so it favors ground truth over the cheap probe the same way
        Install-WingetPackageSafe's own post-install re-check does: it uses Get-Command, not
        Test-CommandAvailable.

        A package whose exe is already gone is treated as success (nothing to do). Otherwise it loads
        Microsoft.WinGet.Client on demand, calls Uninstall-WinGetPackage, and re-checks Get-Command
        afterward as the real success signal — a benign non-zero result code is not treated as failure,
        and a silent no-op is. Nothing here throws; a failure is reported with Write-Warning and a
        $false return, so the caller can keep going through the rest of the checked items.

    .PARAMETER Id
        The winget package id to uninstall, e.g. 'ajeetdsouza.zoxide' — the same id
        Install-WingetPackageSafe was given.

    .PARAMETER Exe
        The executable to probe with Get-Command, e.g. 'zoxide.exe'. Both the short-circuit and the
        success check key off this.

    .PARAMETER CallerName
        The calling function's name, used to prefix the diagnostic warning so the failing removal is
        identifiable, e.g. 'Uninstall-PwshProfile'.

    .EXAMPLE
        Uninstall-WingetPackageSafe -Id 'ajeetdsouza.zoxide' -Exe 'zoxide.exe' -CallerName 'Uninstall-PwshProfile'

        Removes zoxide via winget, returning $true only if it is genuinely gone afterward.

    .NOTES
        Deliberately returns [bool] rather than being void like Install-WingetPackageSafe: its caller
        records per-item success in a -PassThru result, which the install side never needed (it only
        ever recorded a package name into $script:StartupInstall for its own aggregate notice).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Id,

        [Parameter(Mandatory, Position = 1)]
        [string]$Exe,

        [Parameter(Mandatory)]
        [string]$CallerName
    )

    if (-not (Get-Command $Exe -ErrorAction SilentlyContinue)) { return $true }

    Import-ModuleSafe Microsoft.WinGet.Client
    if (-not (Get-Command Uninstall-WinGetPackage -ErrorAction SilentlyContinue)) {
        Write-Warning "${CallerName}: Microsoft.WinGet.Client is unavailable; cannot uninstall $Id."
        return $false
    }

    # Suppress the cmdlet's progress so it doesn't tear a live Spectre spinner, if one is running.
    $prevProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        Uninstall-WinGetPackage -Id $Id -Source winget -Mode Silent | Out-Null
    }
    catch {
        Write-Warning "${CallerName}: Uninstall-WinGetPackage of $Id threw: $($_.Exception.Message)"
    }
    finally {
        $ProgressPreference = $prevProgress
    }

    # Ground truth beats the result code: if the exe is still resolvable, it didn't take.
    if (Get-Command $Exe -ErrorAction SilentlyContinue) {
        Write-Warning "${CallerName}: uninstall of $Id did not remove $Exe from PATH."
        return $false
    }

    $true
}
