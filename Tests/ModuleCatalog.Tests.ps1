#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'

    # Every module name a real Import-ModuleSafe call passes, read from the module's own source.
    #
    # Parsed rather than grepped: 'Import-ModuleSafe Terminal-Icons' also appears inside comment-based
    # help in half a dozen files, and a text search would count those as call sites. The AST sees only
    # code, so the two sets can be compared exactly.
    function Get-ImportedModuleName {
        $root = Join-Path $PSScriptRoot '..'
        $files = @(
            Get-ChildItem -Path (Join-Path $root 'Public') -Recurse -File -Filter '*.ps1'
            Get-ChildItem -Path (Join-Path $root 'Private') -Recurse -File -Filter '*.ps1'
            Get-Item -Path (Join-Path $root 'Suffix.ps1')
            Get-Item -Path (Join-Path $root 'Prefix.ps1')
        )
        $names = foreach ($file in $files) {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
            $calls = $ast.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.CommandAst] -and
                    $node.GetCommandName() -eq 'Import-ModuleSafe'
                }, $true)
            foreach ($call in $calls) {
                # Element 0 is the command name; element 1 is the module, always passed positionally.
                $argument = @($call.CommandElements)[1]
                if ($argument -is [System.Management.Automation.Language.ConstantExpressionAst]) { $argument.Value }
            }
        }
        @($names | Sort-Object -Unique)
    }
}

Describe 'Get-PwshProfileModuleCatalog' {
    It 'gives every module a name, a label, a declared Detail, and a Url' {
        InModuleScope $script:Module {
            foreach ($row in Get-PwshProfileModuleCatalog) {
                @($row.PSObject.Properties.Name) | Sort-Object | Should -Be @('Detail', 'Label', 'Name', 'Url')
                $row.Name | Should -Not -BeNullOrEmpty
                $row.Label | Should -Not -BeNullOrEmpty
                # Detail may be $null, but the property must exist: the suite runs under
                # Set-StrictMode -Version Latest, where reading an omitted property throws.
                $row.Label | Should -BeLike "$($row.Name)*" -Because 'the label should lead with the module name'
                $row.Url | Should -Match '^https://' -Because "'$($row.Name)' should link to its project"
            }
        }
    }

    It 'lists each module once' {
        InModuleScope $script:Module {
            $rows = @(Get-PwshProfileModuleCatalog)
            @($rows.Name | Sort-Object -Unique).Count | Should -Be $rows.Count
        }
    }

    It 'covers exactly the modules Import-ModuleSafe actually installs (anti-drift)' {
        # The point of the Modules step is that nothing lands on the machine unannounced, so this has
        # to hold in BOTH directions: a new Import-ModuleSafe call with no catalog row is an
        # undisclosed install, and a catalog row with no call site is a promise about something the
        # profile never fetches.
        $imported = Get-ImportedModuleName
        $catalog = @(& (Get-Module $script:Module) { Get-PwshProfileModuleCatalog }).Name | Sort-Object -Unique
        $catalog | Should -Be $imported
    }
}

Describe 'Get-PwshProfileModuleInventory' {
    It 'covers exactly the catalog rows, in order' {
        InModuleScope $script:Module {
            @((Get-PwshProfileModuleInventory).Name) | Should -Be @((Get-PwshProfileModuleCatalog).Name)
        }
    }

    It 'carries the fields the renderer needs' {
        InModuleScope $script:Module {
            foreach ($row in Get-PwshProfileModuleInventory) {
                @($row.PSObject.Properties.Name) | Sort-Object |
                    Should -Be @('Detail', 'Installed', 'Label', 'Name', 'Url')
            }
        }
    }

    It 'passes Url through untouched from the catalog' {
        InModuleScope $script:Module {
            @((Get-PwshProfileModuleInventory).Url) | Should -Be @((Get-PwshProfileModuleCatalog).Url)
        }
    }

    It 'marks a row installed exactly when the probe says so' {
        # It must agree with what Import-ModuleSafe would do, and it uses the same Test-ModuleAvailable
        # call that helper uses to decide -- so flipping the probe flips every row.
        InModuleScope $script:Module {
            Mock Test-ModuleAvailable { $true }
            @(Get-PwshProfileModuleInventory | Where-Object { -not $_.Installed }) | Should -BeNullOrEmpty

            Mock Test-ModuleAvailable { $false }
            @(Get-PwshProfileModuleInventory | Where-Object { $_.Installed }) | Should -BeNullOrEmpty
        }
    }

    It 'probes each module by its own name' {
        InModuleScope $script:Module {
            Mock Test-ModuleAvailable { $true }
            $null = Get-PwshProfileModuleInventory
            foreach ($module in Get-PwshProfileModuleCatalog) {
                Should -Invoke Test-ModuleAvailable -Times 1 -Exactly -ParameterFilter { $Name -eq $module.Name }
            }
        }
    }

    It 'installs nothing itself' {
        # Reporting only. Import-ModuleSafe still installs each module at the point of use, which is
        # why a row can read "will install" and never be fetched in a session that never reaches it.
        InModuleScope $script:Module {
            Mock Import-ModuleSafe { }
            $null = Get-PwshProfileModuleInventory
            Should -Invoke Import-ModuleSafe -Times 0 -Exactly
        }
    }
}
