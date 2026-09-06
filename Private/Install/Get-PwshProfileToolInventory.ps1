function Get-PwshProfileToolInventory {
    <#
    .SYNOPSIS
        Returns the winget tool catalog with each row marked present or missing on this machine.

    .DESCRIPTION
        Projects Get-PwshProfileToolCatalog's winget rows through Test-CommandAvailable, adding an
        Installed bool to each. Pure data — Show-PwshProfileInventory renders it, and splitting
        the two keeps this testable without touching the console.

        It probes with the SAME call Install-WingetPackageSafe uses as its already-installed
        short-circuit, so the inventory agrees with what the install will actually do by construction
        rather than by coincidence. If that probe is ever changed, both move together.

        Deliberately uncached, for the same reason Test-CommandAvailable itself is: installing patches
        the current session's $env:Path, so an answer cached before an install would be stale during
        the very phase this exists to report on. The cost is a $env:Path walk per tool — roughly 8ms
        on a miss and far less on a hit, so well under 100ms for the whole catalog.

    .EXAMPLE
        Get-PwshProfileToolInventory

        Returns every winget tool row with an Installed flag.

    .EXAMPLE
        @(Get-PwshProfileToolInventory | Where-Object { -not $_.Installed }).Count

        How many packages the next install would actually fetch.

    .NOTES
        Only the winget rows are inventoried — which is now every package setup puts on the machine,
        git and oh-my-posh included since they joined the catalog. The 'module' and 'none' kinds have no
        exe to probe: the config-only rows install nothing, and the PowerShell modules are covered
        separately by Get-PwshProfileModuleInventory, which probes with Test-ModuleAvailable instead.

        PathDir and Scope are carried through untouched so Install-PwshProfile can forward them. They
        are $null for a portable; dropping them would send git and oh-my-posh to the shared Links
        directory, so the install would land elsewhere and the post-install PATH re-check would warn.

        Url is carried through untouched too — Show-PwshProfileInventory renders it as a clickable
        link on the row's label.
    #>
    [CmdletBinding()]
    param()

    foreach ($tool in (Get-PwshProfileToolCatalog)['WinGet']) {
        [pscustomobject]@{
            Label     = $tool.Label
            Token     = $tool.Token
            PackageId = $tool.PackageId
            Exe       = $tool.Exe
            PathDir   = $tool.PathDir
            Scope     = $tool.Scope
            Url       = $tool.Url
            Installed = [bool](Test-CommandAvailable -Name $tool.Exe)
        }
    }
}
