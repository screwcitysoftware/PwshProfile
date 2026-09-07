function Get-PwshProfileRemovalInventory {
    <#
    .SYNOPSIS
        Returns everything Uninstall-PwshProfile's checkbox can offer to remove: installed winget
        tools, installed gallery modules, and the Windows Terminal color scheme, if present.

    .DESCRIPTION
        Pure data, no console output — Read-PwshProfileUninstallTree renders it, and splitting the two
        keeps this testable without a real Spectre prompt, the same split used for the install
        wizard's own tool/module inventories.

        Three groups, each a projection of an existing catalog filtered to what is actually installed:
          WinGet Tools     — Get-PwshProfileToolInventory, filtered to Installed rows.
          Modules          — Get-PwshProfileModuleInventory, filtered to Installed rows, EXCLUDING
                              NerdFonts: fonts have no clean uninstall API (the NerdFonts module only
                              exports Install-NerdFont/Get-NerdFont), so they are never offered here.
          Windows Terminal — at most one row, for the color scheme belonging to -Theme, and only when
                              Get-WindowsTerminalSchemeName shows it is actually present. Install-PwshProfile
                              installs at most one bundled scheme (whichever theme the wizard configured,
                              falling back to 'screwcity' for a custom theme, same as its own runtime
                              color/icon resolution) — so at most one row can ever apply.

        Every row declares every property (Group, Label, Kind, Id, Exe, Name, Theme), $null where not
        applicable, since the suite runs under Set-StrictMode -Version Latest.

        Label uniqueness across the whole set is required — Read-PwshProfileUninstallTree keys
        selection by the label string. True by construction: tool and module Labels are already pinned
        unique by Tests/ToolCatalog.Tests.ps1 and Tests/ModuleCatalog.Tests.ps1, and the Windows
        Terminal row is the only one of its Kind.

    .PARAMETER Theme
        The bundled theme whose Windows Terminal scheme to look for. Defaults to 'screwcity', the same
        fallback Install-PwshProfile itself uses when resolving a Windows Terminal scheme theme.

    .EXAMPLE
        Get-PwshProfileRemovalInventory -Theme 'forestcity'

        Returns every installed tool/module row, plus a Windows Terminal row if the 'Forest City'
        scheme is present in settings.json.

    .NOTES
        Reporting only. Nothing here removes anything — Uninstall-PwshProfile does that, through
        Uninstall-WingetPackageSafe / Uninstall-ModuleSafe / Uninstall-WindowsTerminalScheme.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Theme = 'screwcity'
    )

    $rows = [System.Collections.Generic.List[object]]::new()

    foreach ($tool in (Get-PwshProfileToolInventory | Where-Object Installed)) {
        $rows.Add([pscustomobject]@{
                Group = 'WinGet Tools'; Label = $tool.Label; Kind = 'Tool'
                Id    = $tool.PackageId; Exe = $tool.Exe; Name = $null; Theme = $null
            })
    }

    foreach ($module in (Get-PwshProfileModuleInventory | Where-Object { $_.Installed -and $_.Name -ne 'NerdFonts' })) {
        $rows.Add([pscustomobject]@{
                Group = 'Modules'; Label = $module.Label; Kind = 'Module'
                Id    = $null; Exe = $null; Name = $module.Name; Theme = $null
            })
    }

    $schemeName = (Get-BundledThemeBranding -Name $Theme).TerminalScheme['name']
    if ($schemeName -in @(Get-WindowsTerminalSchemeName)) {
        $rows.Add([pscustomobject]@{
                Group = 'Windows Terminal'; Label = "Windows Terminal color scheme '$schemeName'"
                Kind  = 'TerminalScheme'; Id = $null; Exe = $null; Name = $null; Theme = $Theme
            })
    }

    $rows.ToArray()
}
