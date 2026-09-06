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
                    Should -Be @('Exe', 'Installed', 'Label', 'PackageId', 'PathDir', 'Scope', 'Token')
                $row.Label | Should -Not -BeNullOrEmpty
                $row.PackageId | Should -Not -BeNullOrEmpty
                $row.Exe | Should -Not -BeNullOrEmpty
            }
        }
    }

    It 'passes the install location straight through from the catalog' {
        # Dropping PathDir/Scope here would have Install-PwshProfile install git and oh-my-posh to the
        # shared portable Links dir rather than their own: the package would land correctly and the
        # post-install PATH re-check would then warn about an install that had actually worked.
        InModuleScope $script:Module {
            $inventory = @(Get-PwshProfileToolInventory)
            foreach ($tool in (Get-PwshProfileToolCatalog)['WinGet']) {
                $row = $inventory | Where-Object { $_.Token -eq $tool.Token }
                "$($row.PathDir)" | Should -Be "$($tool.PathDir)"
                "$($row.Scope)" | Should -Be "$($tool.Scope)"
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

Describe 'Show-PwshProfileInventory' {
    BeforeEach {
        $script:Rows = @(
            [pscustomobject]@{ Label = 'zoxide (smart cd)'; Token = 'Zoxide'; PackageId = 'a.b'; Exe = 'zoxide.exe'; Installed = $true }
            [pscustomobject]@{ Label = 'uv (Python toolchain)'; Token = 'Uv'; PackageId = 'astral-sh.uv'; Exe = 'uv.exe'; Installed = $false }
        )
    }

    It 'marks present rows with a check and missing rows with a down-arrow' {
        InModuleScope $script:Module -Parameters @{ R = $script:Rows } {
            param($R)
            Mock Write-SpectreHost { }
            Show-PwshProfileInventory -Row $R
            Should -Invoke Write-SpectreHost -Times 1 -Exactly -ParameterFilter { $Message -like '*✓*zoxide*' }
            Should -Invoke Write-SpectreHost -Times 1 -Exactly -ParameterFilter { $Message -like '*↓*uv (Python toolchain)*' }
            # Deliberately not a cross: a tool that simply hasn't been fetched yet is the expected
            # state on a clean machine, not a failure.
            Should -Invoke Write-SpectreHost -Times 0 -Exactly -ParameterFilter { $Message -like '*✗*' }
        }
    }

    It 'reads rows that carry no Detail property at all' {
        # The tool rows deliberately don't have that column, and reading a property a PSCustomObject
        # omits throws under Set-StrictMode -Version Latest, which is how the suite and CI run.
        InModuleScope $script:Module -Parameters @{ R = $script:Rows } {
            param($R)
            Set-StrictMode -Version Latest
            Mock Write-SpectreHost { }
            { Show-PwshProfileInventory -Row $R } | Should -Not -Throw
        }
    }

    It 'marks a conditional row with a dot and its own reason rather than "will install"' {
        # A flat "will install" would be a promise the install may never keep -- DockerCompletion on a
        # machine with no docker is the case in point.
        InModuleScope $script:Module {
            Mock Write-SpectreHost { }
            $row = [pscustomobject]@{ Label = 'DockerCompletion'; Installed = $false; Detail = 'only when docker is on PATH' }
            Show-PwshProfileInventory -Row @($row)
            Should -Invoke Write-SpectreHost -Times 1 -Exactly `
                -ParameterFilter { $Message -like '*·*DockerCompletion*only when docker is on PATH*' }
            Should -Invoke Write-SpectreHost -Times 0 -Exactly -ParameterFilter { $Message -like '*will install*' }
            Should -Invoke Write-SpectreHost -Times 1 -Exactly -ParameterFilter { $Message -like '*1 only if needed*' }
        }
    }

    It 'ignores Detail on a row that is already installed' {
        InModuleScope $script:Module {
            Mock Write-SpectreHost { }
            $row = [pscustomobject]@{ Label = 'NerdFonts'; Installed = $true; Detail = 'only if you opt into Nerd Fonts' }
            Show-PwshProfileInventory -Row @($row)
            Should -Invoke Write-SpectreHost -Times 1 -Exactly -ParameterFilter { $Message -like '*✓*NerdFonts*already installed*' }
            Should -Invoke Write-SpectreHost -Times 1 -Exactly -ParameterFilter { $Message -like '*all 1 already installed*' }
        }
    }

    It 'renders rows, not a panel' {
        # It draws inside a wizard step, under that step's own header panel -- a panel nested in a
        # panel reads wrong, and Format-SpectrePanel would also need an Out-Host to stop its rendered
        # string leaking into the caller's return value.
        InModuleScope $script:Module -Parameters @{ R = $script:Rows } {
            param($R)
            Mock Write-SpectreHost { }
            Mock Format-SpectrePanel { } -RemoveParameterType 'Color'
            Show-PwshProfileInventory -Row $R
            Should -Invoke Format-SpectrePanel -Times 0 -Exactly
        }
    }

    It 'reports the split when some are missing' {
        InModuleScope $script:Module -Parameters @{ R = $script:Rows } {
            param($R)
            Mock Write-SpectreHost { }
            Show-PwshProfileInventory -Row $R
            Should -Invoke Write-SpectreHost -Times 1 -Exactly `
                -ParameterFilter { $Message -like '*1 present*1 to install*' }
        }
    }

    It 'says so plainly when nothing needs installing' {
        InModuleScope $script:Module -Parameters @{ R = $script:Rows } {
            param($R)
            Mock Write-SpectreHost { }
            $all = @($R | ForEach-Object { $_.Installed = $true; $_ })
            Show-PwshProfileInventory -Row $all
            Should -Invoke Write-SpectreHost -Times 1 -Exactly `
                -ParameterFilter { $Message -like '*all 2 already installed*' }
            Should -Invoke Write-SpectreHost -Times 0 -Exactly `
                -ParameterFilter { $Message -like '*to install*' -and $Message -notlike '*already installed*' }
        }
    }

    It 'falls back to the tool inventory when given no rows' {
        InModuleScope $script:Module {
            Mock Write-SpectreHost { }
            Mock Get-PwshProfileToolInventory { @([pscustomobject]@{ Label = 'jq'; Installed = $true }) }
            Show-PwshProfileInventory
            Should -Invoke Get-PwshProfileToolInventory -Times 1 -Exactly
        }
    }

    It 'returns nothing to the pipeline' {
        # Rows go straight to the console via Write-SpectreHost. Guarded because the obvious
        # alternative -- Format-SpectrePanel -- emits its rendered string to the PIPELINE, and would
        # silently leak into whatever the caller returns.
        InModuleScope $script:Module -Parameters @{ R = $script:Rows } {
            param($R)
            Mock Write-SpectreHost { }
            $captured = Show-PwshProfileInventory -Row $R
            $captured | Should -BeNullOrEmpty
        }
    }

    It 'renders without Spectre' {
        InModuleScope $script:Module -Parameters @{ R = $script:Rows } {
            param($R)
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Write-SpectreHost' }
            Mock Write-Host { }
            { Show-PwshProfileInventory -Row $R } | Should -Not -Throw
            Should -Invoke Write-Host -Times 1 -Exactly
        }
    }

    It 'does nothing for an empty inventory' {
        InModuleScope $script:Module {
            Mock Write-SpectreHost { }
            Mock Write-Host { }
            Show-PwshProfileInventory -Row @()
            Should -Invoke Write-Host -Times 0 -Exactly
        }
    }
}
