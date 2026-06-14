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
}
