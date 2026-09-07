#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
}

Describe 'Get-PwshProfileRemovalInventory' {
    It 'declares all six properties on every row' {
        # The suite runs under Set-StrictMode -Version Latest, where reading a property a row omitted
        # throws rather than returning $null.
        InModuleScope $script:Module {
            Mock Test-CommandAvailable { $true }
            Mock Test-ModuleAvailable { $true }
            Mock Get-WindowsTerminalSchemeName { @('Screw City') }
            foreach ($row in Get-PwshProfileRemovalInventory) {
                @($row.PSObject.Properties.Name) | Sort-Object |
                    Should -Be @('Exe', 'Group', 'Id', 'Kind', 'Label', 'Name', 'Theme')
            }
        }
    }

    It 'includes every winget catalog token as a Tool row when everything is installed' {
        InModuleScope $script:Module {
            Mock Test-CommandAvailable { $true }
            Mock Test-ModuleAvailable { $true }
            Mock Get-WindowsTerminalSchemeName { @() }
            $rows = @(Get-PwshProfileRemovalInventory | Where-Object Kind -eq 'Tool')
            $expected = @((Get-PwshProfileToolCatalog)['WinGet'].Token)
            @($rows.Id) | Should -Be @((Get-PwshProfileToolCatalog)['WinGet'].PackageId)
            $rows.Count | Should -Be $expected.Count
        }
    }

    It 'includes every module catalog entry except NerdFonts as a Module row when everything is installed' {
        # Fonts have no clean uninstall API -- NerdFonts is deliberately never offered here.
        InModuleScope $script:Module {
            Mock Test-CommandAvailable { $true }
            Mock Test-ModuleAvailable { $true }
            Mock Get-WindowsTerminalSchemeName { @() }
            $rows = @(Get-PwshProfileRemovalInventory | Where-Object Kind -eq 'Module')
            @($rows.Name) | Should -Not -Contain 'NerdFonts'
            $expected = @((Get-PwshProfileModuleCatalog | Where-Object Name -ne 'NerdFonts').Name)
            @($rows.Name | Sort-Object) | Should -Be @($expected | Sort-Object)
        }
    }

    It 'includes exactly one Windows Terminal row when the theme''s scheme is present' {
        InModuleScope $script:Module {
            Mock Test-CommandAvailable { $false }
            Mock Test-ModuleAvailable { $false }
            Mock Get-WindowsTerminalSchemeName { @('Screw City') }
            $rows = @(Get-PwshProfileRemovalInventory -Theme 'screwcity' | Where-Object Kind -eq 'TerminalScheme')
            $rows.Count | Should -Be 1
            $rows[0].Theme | Should -Be 'screwcity'
        }
    }

    It 'omits the Windows Terminal row when the scheme is not present' {
        InModuleScope $script:Module {
            Mock Test-CommandAvailable { $false }
            Mock Test-ModuleAvailable { $false }
            Mock Get-WindowsTerminalSchemeName { @() }
            @(Get-PwshProfileRemovalInventory -Theme 'screwcity' | Where-Object Kind -eq 'TerminalScheme') |
                Should -BeNullOrEmpty
        }
    }

    It 'returns nothing when nothing is installed' {
        InModuleScope $script:Module {
            Mock Test-CommandAvailable { $false }
            Mock Test-ModuleAvailable { $false }
            Mock Get-WindowsTerminalSchemeName { @() }
            @(Get-PwshProfileRemovalInventory) | Should -BeNullOrEmpty
        }
    }

    It 'gives every row a label unique across the whole set' {
        # Load-bearing, not cosmetic: Read-PwshProfileUninstallTree keys selection by the label string.
        InModuleScope $script:Module {
            Mock Test-CommandAvailable { $true }
            Mock Test-ModuleAvailable { $true }
            Mock Get-WindowsTerminalSchemeName { @('Screw City') }
            $rows = @(Get-PwshProfileRemovalInventory)
            @($rows.Label | Sort-Object -Unique).Count | Should -Be $rows.Count
        }
    }
}
