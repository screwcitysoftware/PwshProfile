#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
}

Describe 'Get-PwshProfileToolInventory' {
    It 'covers exactly the winget catalog rows' {
        InModuleScope $script:Module {
            $inventory = @(Get-PwshProfileToolInventory)
            $expected = @((Get-PwshProfileToolCatalog)['WinGet'])
            @($inventory.Token) | Should -Be @($expected.Token)
        }
    }

    It 'carries the fields the renderer and the installer both need' {
        InModuleScope $script:Module {
            foreach ($row in Get-PwshProfileToolInventory) {
                @($row.PSObject.Properties.Name) | Sort-Object |
                    Should -Be @('Exe', 'Installed', 'Label', 'PackageId', 'Token')
                $row.Label | Should -Not -BeNullOrEmpty
                $row.PackageId | Should -Not -BeNullOrEmpty
                $row.Exe | Should -Not -BeNullOrEmpty
            }
        }
    }

    It 'marks a row installed exactly when the probe says so' {
        # The inventory must agree with what the install will actually do. It uses the same
        # Test-CommandAvailable call Install-WingetPackageSafe uses as its short-circuit, so flipping
        # the probe must flip every row -- if it didn't, the panel would promise one thing and the
        # install do another.
        InModuleScope $script:Module {
            Mock Test-CommandAvailable { $true }
            @(Get-PwshProfileToolInventory | Where-Object { -not $_.Installed }) | Should -BeNullOrEmpty

            Mock Test-CommandAvailable { $false }
            @(Get-PwshProfileToolInventory | Where-Object { $_.Installed }) | Should -BeNullOrEmpty
        }
    }

    It 'probes each tool by its own exe' {
        InModuleScope $script:Module {
            Mock Test-CommandAvailable { $true }
            $null = Get-PwshProfileToolInventory
            foreach ($tool in (Get-PwshProfileToolCatalog)['WinGet']) {
                Should -Invoke Test-CommandAvailable -Times 1 -Exactly -ParameterFilter { $Name -eq $tool.Exe }
            }
        }
    }
}

Describe 'Show-PwshProfileToolInventory' {
    BeforeEach {
        $script:Rows = @(
            [pscustomobject]@{ Label = 'zoxide (smart cd)'; Token = 'Zoxide'; PackageId = 'a.b'; Exe = 'zoxide.exe'; Installed = $true }
            [pscustomobject]@{ Label = 'uv (Python toolchain)'; Token = 'Uv'; PackageId = 'astral-sh.uv'; Exe = 'uv.exe'; Installed = $false }
        )
    }

    # The rendered panel goes to the HOST via Out-Host, so it can't be captured from a stream --
    # asserting on what is handed to Format-SpectrePanel is both possible and closer to the point:
    # that string is exactly the content the panel draws.
    It 'marks present rows with a check and missing rows with a down-arrow' {
        InModuleScope $script:Module -Parameters @{ R = $script:Rows } {
            param($R)
            Mock Write-SpectreHost { }
            Mock Format-SpectrePanel { } -RemoveParameterType 'Color'
            Show-PwshProfileToolInventory -Tool $R
            Should -Invoke Format-SpectrePanel -Times 1 -Exactly -ParameterFilter { $Data -like '*✓*zoxide*' }
            Should -Invoke Format-SpectrePanel -Times 1 -Exactly -ParameterFilter { $Data -like '*↓*uv (Python toolchain)*' }
            # Deliberately not a cross: a tool that simply hasn't been fetched yet is the expected
            # state on a clean machine, not a failure.
            Should -Invoke Format-SpectrePanel -Times 0 -Exactly -ParameterFilter { $Data -like '*✗*' }
        }
    }

    It 'reports the split when some are missing' {
        InModuleScope $script:Module -Parameters @{ R = $script:Rows } {
            param($R)
            Mock Write-SpectreHost { }
            Mock Format-SpectrePanel { } -RemoveParameterType 'Color'
            Show-PwshProfileToolInventory -Tool $R
            Should -Invoke Format-SpectrePanel -Times 1 -Exactly `
                -ParameterFilter { $Data -like '*1 present*1 to install*' }
        }
    }

    It 'says so plainly when nothing needs installing' {
        InModuleScope $script:Module -Parameters @{ R = $script:Rows } {
            param($R)
            Mock Write-SpectreHost { }
            Mock Format-SpectrePanel { } -RemoveParameterType 'Color'
            $all = @($R | ForEach-Object { $_.Installed = $true; $_ })
            Show-PwshProfileToolInventory -Tool $all
            Should -Invoke Format-SpectrePanel -Times 1 -Exactly `
                -ParameterFilter { $Data -like '*all 2 already installed*' -and $Data -notlike '*to install*' }
        }
    }

    It 'writes to the host, never to the pipeline' {
        # Format-SpectrePanel emits its rendered string to the PIPELINE, so without the internal
        # Out-Host the panel would leak into the caller's return value -- the same bug the wizard's
        # step-header has a regression test for.
        InModuleScope $script:Module -Parameters @{ R = $script:Rows } {
            param($R)
            $captured = Show-PwshProfileToolInventory -Tool $R 6> $null
            $captured | Should -BeNullOrEmpty
        }
    }

    It 'renders without Spectre' {
        InModuleScope $script:Module -Parameters @{ R = $script:Rows } {
            param($R)
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Write-SpectreHost' }
            Mock Write-Host { }
            { Show-PwshProfileToolInventory -Tool $R } | Should -Not -Throw
            Should -Invoke Write-Host -Times 1 -Exactly
        }
    }

    It 'does nothing for an empty inventory' {
        InModuleScope $script:Module {
            Mock Write-SpectreHost { }
            Mock Write-Host { }
            Show-PwshProfileToolInventory -Tool @()
            Should -Invoke Write-Host -Times 0 -Exactly
        }
    }
}
