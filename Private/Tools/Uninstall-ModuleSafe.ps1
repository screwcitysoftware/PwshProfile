function Uninstall-ModuleSafe {
    <#
    .SYNOPSIS
        Uninstalls a PowerShell Gallery module, the inverse of Import-ModuleSafe's on-demand install.

    .DESCRIPTION
        A one-shot user action (called from Uninstall-PwshProfile's removal checkbox). Import-ModuleSafe
        installs a missing module via Install-PSResource (Microsoft.PowerShell.PSResourceGet); this
        calls that same module's Uninstall-PSResource as the natural inverse.

        A module that is already gone is treated as success. Otherwise it first removes the module from
        the current session (Remove-Module -Force) — the checkbox rendering it is itself driven by
        PwshSpectreConsole, which is guaranteed loaded while the prompt is showing, and
        Uninstall-PSResource cannot remove a module that is still imported — then uninstalls it from
        disk. Nothing here throws; a failure is reported with Write-Warning and a $false return.

        Removing an in-use module here does not break the running session: it stays loaded in memory
        for the rest of this process, it simply will not be found the next time something looks for it.
        Import-ModuleSafe reinstalling it on its next use is expected, not a bug to guard against.

    .PARAMETER Name
        The gallery module name to uninstall, e.g. 'PSFzf' — the same name Import-ModuleSafe was called
        with.

    .PARAMETER CallerName
        The calling function's name, used to prefix the diagnostic warning so the failing removal is
        identifiable, e.g. 'Uninstall-PwshProfile'.

    .EXAMPLE
        Uninstall-ModuleSafe -Name 'PSFzf' -CallerName 'Uninstall-PwshProfile'

        Removes the PSFzf module from disk, returning $true only if it is genuinely gone afterward.

    .NOTES
        Returns [bool] so its caller can record per-item success in a -PassThru result.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$CallerName
    )

    if (-not (Test-ModuleAvailable -Name $Name)) { return $true }

    Remove-Module -Name $Name -Force -ErrorAction SilentlyContinue

    try {
        Uninstall-PSResource -Name $Name -ErrorAction Stop
    }
    catch {
        Write-Warning "${CallerName}: Uninstall-PSResource of $Name threw: $($_.Exception.Message)"
        return $false
    }

    if (Test-ModuleAvailable -Name $Name) {
        Write-Warning "${CallerName}: uninstall of $Name did not remove it."
        return $false
    }

    $true
}
