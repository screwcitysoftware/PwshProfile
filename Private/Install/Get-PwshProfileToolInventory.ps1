function Get-PwshProfileToolInventory {
    <#
    .SYNOPSIS
        Returns the winget tool catalog with each row marked present or missing on this machine.

    .DESCRIPTION
        Projects Get-PwshProfileToolCatalog's winget rows through Test-CommandAvailable, adding an
        Installed bool to each. Pure data — Show-PwshProfileToolInventory renders it, and splitting
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
        Only the winget rows are inventoried. The 'module' and 'none' install kinds have no exe to
        probe — Terminal-Icons and posh-git come from the gallery through Import-ModuleSafe, and the
        rest is config — so they would have nothing meaningful to report.
    #>
    [CmdletBinding()]
    param()

    foreach ($tool in (Get-PwshProfileToolCatalog)['WinGet']) {
        [pscustomobject]@{
            Label     = $tool.Label
            Token     = $tool.Token
            PackageId = $tool.PackageId
            Exe       = $tool.Exe
            Installed = [bool](Test-CommandAvailable -Name $tool.Exe)
        }
    }
}
