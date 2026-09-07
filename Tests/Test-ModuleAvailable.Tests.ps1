#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'

    # A fake PSModulePath root holding one module-shaped folder, so the directory probe can be
    # exercised without depending on what happens to be installed on the machine running the tests.
    $script:FakeRoot = Join-Path ([System.IO.Path]::GetTempPath()) "scs-mods-$([guid]::NewGuid())"
    $null = New-Item -ItemType Directory -Path (Join-Path $script:FakeRoot 'ScsInstalledModule') -Force
}

AfterAll {
    if ($script:FakeRoot -and (Test-Path $script:FakeRoot)) {
        Remove-Item -LiteralPath $script:FakeRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Test-ModuleAvailable' {
    # $env:PSModulePath is process-global, so a Describe-level save/restore covers every It below.
    BeforeEach { $script:savedPSModulePath = $env:PSModulePath }
    AfterEach { $env:PSModulePath = $script:savedPSModulePath }

    Context 'a module that is already loaded' {
        It 'reports available without consulting PSModulePath' {
            # Get-Module answering non-null is the whole check; PSModulePath is emptied to prove the
            # directory probe is never needed to reach $true.
            InModuleScope $script:Module {
                Mock Get-Module { @{ Name = 'AnyName' } }
                $env:PSModulePath = ''
                Test-ModuleAvailable -Name 'AnyName' | Should -BeTrue
            }
        }
    }

    Context 'a module that is installed but not loaded' {
        It 'finds it by directory on PSModulePath' {
            InModuleScope $script:Module -Parameters @{ Root = $script:FakeRoot } {
                param($Root)
                Mock Get-Module { $null }
                $env:PSModulePath = $Root
                Test-ModuleAvailable -Name 'ScsInstalledModule' | Should -BeTrue
            }
        }
    }

    Context 'a module that is neither loaded nor installed' {
        It 'reports unavailable, which is what triggers the install' {
            InModuleScope $script:Module -Parameters @{ Root = $script:FakeRoot } {
                param($Root)
                Mock Get-Module { $null }
                $env:PSModulePath = $Root
                Test-ModuleAvailable -Name 'ScsMissingModule' | Should -BeFalse
            }
        }
    }

    Context 'a malformed PSModulePath' {
        It 'skips empty entries rather than throwing' {
            InModuleScope $script:Module -Parameters @{ Root = $script:FakeRoot } {
                param($Root)
                Mock Get-Module { $null }
                $sep = [System.IO.Path]::PathSeparator
                $env:PSModulePath = "$sep$sep$Root$sep"
                { Test-ModuleAvailable -Name 'ScsInstalledModule' } | Should -Not -Throw
                Test-ModuleAvailable -Name 'ScsInstalledModule' | Should -BeTrue
            }
        }
    }

    Context 'agreement with the enumerating form it replaced' {
        It 'matches Get-Module -ListAvailable for the modules this profile loads' {
            # A false negative here would mean a needless gallery install on every shell start, so the
            # cheap probe must never disagree with the authoritative lookup on real modules.
            foreach ($name in 'PwshSpectreConsole', 'Terminal-Icons', 'posh-git', 'PSFzf', 'ScsDefinitelyNotInstalled') {
                $expected = [bool](Get-Module -ListAvailable -Name $name)
                $actual = InModuleScope $script:Module -Parameters @{ Name = $name } {
                    param($Name)
                    Test-ModuleAvailable -Name $Name
                }
                $actual | Should -Be $expected -Because "Test-ModuleAvailable should agree with Get-Module -ListAvailable for '$name'"
            }
        }
    }
}
