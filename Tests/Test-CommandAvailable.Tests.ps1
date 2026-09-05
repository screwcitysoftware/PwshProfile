#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'

    # A fake PATH entry holding one executable, so the directory probe can be exercised without
    # depending on what happens to be installed on the machine running the tests.
    $script:FakeDir = Join-Path ([System.IO.Path]::GetTempPath()) "scs-path-$([guid]::NewGuid())"
    $null = New-Item -ItemType Directory -Path $script:FakeDir -Force
    Set-Content -LiteralPath (Join-Path $script:FakeDir 'scsfaketool.exe') -Value 'x' -NoNewline
    Set-Content -LiteralPath (Join-Path $script:FakeDir 'scsbatchtool.cmd') -Value 'x' -NoNewline
}

AfterAll {
    if ($script:FakeDir -and (Test-Path $script:FakeDir)) {
        Remove-Item -LiteralPath $script:FakeDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path 'Function:\scsshadowed') { Remove-Item 'Function:\scsshadowed' -Force }
}

Describe 'Test-CommandAvailable' {
    Context 'an executable on PATH' {
        It 'finds a bare name by trying .exe' {
            InModuleScope $script:Module -Parameters @{ Dir = $script:FakeDir } {
                param($Dir)
                $saved = $env:PATH
                try {
                    $env:PATH = $Dir
                    Test-CommandAvailable -Name 'scsfaketool' | Should -BeTrue
                }
                finally { $env:PATH = $saved }
            }
        }

        It 'finds a .cmd shim, which is how the Azure CLI ships' {
            InModuleScope $script:Module -Parameters @{ Dir = $script:FakeDir } {
                param($Dir)
                $saved = $env:PATH
                try {
                    $env:PATH = $Dir
                    Test-CommandAvailable -Name 'scsbatchtool' | Should -BeTrue
                }
                finally { $env:PATH = $saved }
            }
        }

        It 'honors an explicit extension rather than appending another' {
            InModuleScope $script:Module -Parameters @{ Dir = $script:FakeDir } {
                param($Dir)
                $saved = $env:PATH
                try {
                    $env:PATH = $Dir
                    Test-CommandAvailable -Name 'scsfaketool.exe' | Should -BeTrue
                    Test-CommandAvailable -Name 'scsfaketool.cmd' | Should -BeFalse
                }
                finally { $env:PATH = $saved }
            }
        }
    }

    Context 'a command that is not present' {
        It 'reports unavailable, which is what makes the caller skip the tool' {
            InModuleScope $script:Module -Parameters @{ Dir = $script:FakeDir } {
                param($Dir)
                $saved = $env:PATH
                try {
                    $env:PATH = $Dir
                    Test-CommandAvailable -Name 'scsdefinitelymissing' | Should -BeFalse
                }
                finally { $env:PATH = $saved }
            }
        }
    }

    Context 'a function shadowing the name' {
        It 'reports available even with nothing on PATH' {
            # A function beats PATH in real command resolution, so the probe has to agree.
            function global:scsshadowed { 'shadow' }
            InModuleScope $script:Module {
                $saved = $env:PATH
                try {
                    $env:PATH = ''
                    Test-CommandAvailable -Name 'scsshadowed' | Should -BeTrue
                }
                finally { $env:PATH = $saved }
            }
        }
    }

    Context 'a malformed PATH' {
        It 'skips empty entries rather than throwing' {
            InModuleScope $script:Module -Parameters @{ Dir = $script:FakeDir } {
                param($Dir)
                $saved = $env:PATH
                try {
                    $sep = [System.IO.Path]::PathSeparator
                    $env:PATH = "$sep$sep$Dir$sep"
                    { Test-CommandAvailable -Name 'scsfaketool' } | Should -Not -Throw
                    Test-CommandAvailable -Name 'scsfaketool' | Should -BeTrue
                }
                finally { $env:PATH = $saved }
            }
        }
    }

    Context 'agreement with the Get-Command it replaced' {
        It 'matches Get-Command for every tool this module probes' {
            # This is the assertion that matters. A false negative here would silently skip a tool the
            # user actually has installed -- no error, just a feature quietly not working -- so the
            # cheap probe must never disagree with real command resolution on these names.
            $names = 'oh-my-posh.exe', 'bat.exe', 'fd.exe', 'fzf.exe', 'less.exe', 'xh.exe',
                     'xhs.exe', 'zoxide.exe', 'fnm.exe', 'git', 'az', 'docker', 'tailscale',
                     'op', 'gh', 'lazygit', 'scsdefinitelymissing'
            foreach ($name in $names) {
                $expected = [bool](Get-Command $name -ErrorAction SilentlyContinue)
                $actual = InModuleScope $script:Module -Parameters @{ Name = $name } {
                    param($Name)
                    Test-CommandAvailable -Name $Name
                }
                $actual | Should -Be $expected -Because "Test-CommandAvailable should agree with Get-Command for '$name'"
            }
        }
    }
}
