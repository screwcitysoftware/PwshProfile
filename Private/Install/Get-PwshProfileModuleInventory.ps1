function Get-PwshProfileModuleInventory {
    <#
    .SYNOPSIS
        Returns the gallery-module catalog with each row marked present or missing on this machine.

    .DESCRIPTION
        The module-side counterpart to Get-PwshProfileToolInventory: it projects
        Get-PwshProfileModuleCatalog through Test-ModuleAvailable and adds an Installed bool. Pure
        data — Show-PwshProfileInventory renders it, and splitting the two keeps this testable without
        touching the console.

        It probes with the SAME call Import-ModuleSafe uses to decide whether to install, so the list
        agrees with what would actually happen by construction rather than by coincidence. Note that
        probe is deliberately a heuristic (a directory check, not a manifest validation) — a module
        folder with a broken manifest reads as present here and Import-ModuleSafe takes its warn-and-
        continue path, which is the same answer both would have given before.

        Detail is carried through untouched: it is what the renderer shows in place of "will install"
        for a module that is only fetched under some condition.

    .EXAMPLE
        Get-PwshProfileModuleInventory

        Returns every gallery module the profile may install, with an Installed flag.

    .NOTES
        Reporting only. Nothing here installs a module — Import-ModuleSafe still does that at the point
        of use, which is why a row can read "will install" and then never be fetched in a session that
        does not reach it.
    #>
    [CmdletBinding()]
    param()

    foreach ($module in Get-PwshProfileModuleCatalog) {
        [pscustomobject]@{
            Name      = $module.Name
            Label     = $module.Label
            Detail    = $module.Detail
            Installed = [bool](Test-ModuleAvailable -Name $module.Name)
        }
    }
}
