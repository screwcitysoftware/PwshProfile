#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
}

Describe 'Import-ModuleSafe' {
    BeforeEach {
        Mock -ModuleName $script:Module Install-PSResource { }
        Mock -ModuleName $script:Module Import-Module { }
    }

    Context 'module already available' {
        BeforeEach {
            Mock -ModuleName $script:Module Get-Module { @{ Name = 'FakeModule' } }
        }

        It 'imports without installing' {
            Import-ModuleSafe FakeModule
            Should -Invoke -ModuleName $script:Module Install-PSResource -Times 0 -Exactly
            Should -Invoke -ModuleName $script:Module Import-Module -Times 1 -Exactly
        }

        It 'runs the -Initialize block after a successful import' {
            $state = @{ Ran = $false }
            Import-ModuleSafe FakeModule -Initialize { $state.Ran = $true }
            $state.Ran | Should -BeTrue
        }
    }

    Context 'module missing' {
        BeforeEach {
            Mock -ModuleName $script:Module Get-Module { $null }
        }

        It 'installs before importing' {
            Import-ModuleSafe FakeModule
            Should -Invoke -ModuleName $script:Module Install-PSResource -Times 1 -Exactly
            Should -Invoke -ModuleName $script:Module Import-Module -Times 1 -Exactly
        }

        It 'warns and skips the import when the install fails' {
            Mock -ModuleName $script:Module Install-PSResource { throw 'gallery unreachable' }
            $warnings = Import-ModuleSafe FakeModule 3>&1
            "$warnings" | Should -Match "could not install 'FakeModule'"
            Should -Invoke -ModuleName $script:Module Import-Module -Times 0 -Exactly
        }
    }

    Context 'import failure' {
        BeforeEach {
            Mock -ModuleName $script:Module Get-Module { @{ Name = 'FakeModule' } }
            Mock -ModuleName $script:Module Import-Module { throw 'bad module' }
        }

        It 'warns and does not run -Initialize' {
            $state = @{ Ran = $false }
            $warnings = Import-ModuleSafe FakeModule -Initialize { $state.Ran = $true } 3>&1
            "$warnings" | Should -Match "could not import 'FakeModule'"
            $state.Ran | Should -BeFalse
        }
    }

    Context 'import failure with -Repair' {
        BeforeEach {
            Mock -ModuleName $script:Module Get-Module { @{ Name = 'FakeModule' } }
        }

        It 'runs the repair, retries the import once, and does not warn when the retry succeeds' {
            $script:ImportAttempts = 0
            Mock -ModuleName $script:Module Import-Module {
                $script:ImportAttempts++
                if ($script:ImportAttempts -eq 1) { throw 'bad module' }
            }
            $state = @{ Repaired = $false }
            $warnings = Import-ModuleSafe FakeModule -Repair { $state.Repaired = $true } 3>&1
            $state.Repaired | Should -BeTrue
            Should -Invoke -ModuleName $script:Module Import-Module -Times 2 -Exactly
            "$warnings" | Should -Not -Match 'could not import'
        }

        It 'warns after the repair when the retry still fails' {
            Mock -ModuleName $script:Module Import-Module { throw 'bad module' }
            $state = @{ Repaired = $false }
            $warnings = Import-ModuleSafe FakeModule -Repair { $state.Repaired = $true } 3>&1
            $state.Repaired | Should -BeTrue
            "$warnings" | Should -Match "could not import 'FakeModule'"
            Should -Invoke -ModuleName $script:Module Import-Module -Times 2 -Exactly
        }
    }
}
