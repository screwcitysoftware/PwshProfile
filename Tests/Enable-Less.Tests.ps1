#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
}

Describe 'Enable-Less' {
    BeforeEach {
        # Run each substep body inline (no spinner) and never touch winget. less needs no shim — the
        # Initialize substep only sets env vars / an alias, it never shells out to less.exe.
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Mock -ModuleName $script:Module Install-WingetPackageSafe { }

        # $env:LESS / $env:PAGER are process-global; snapshot and clear so assertions are clean.
        $script:savedLess  = $env:LESS
        $script:savedPager = $env:PAGER
        $env:LESS  = $null
        $env:PAGER = $null
        # Drop any pre-existing global `more` alias so the alias assertions are clean.
        Remove-Alias -Name more -Scope Global -Force -ErrorAction SilentlyContinue
    }

    AfterEach {
        Remove-Alias -Name more -Scope Global -Force -ErrorAction SilentlyContinue
        $env:LESS  = $script:savedLess
        $env:PAGER = $script:savedPager
    }

    It 'sets $env:LESS and leaves the pager untouched without -ReplaceMore' {
        Mock -ModuleName $script:Module Get-Command { $true } -ParameterFilter { $Name -eq 'less.exe' }
        Enable-Less -Options '-R'
        $env:LESS  | Should -Be '-R'
        $env:PAGER | Should -BeNullOrEmpty
        Get-Alias more -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'routes the pager through less and aliases more -> less with -ReplaceMore' {
        Mock -ModuleName $script:Module Get-Command { $true } -ParameterFilter { $Name -eq 'less.exe' }
        Enable-Less -ReplaceMore
        $env:PAGER | Should -Be 'less'
        (Get-Alias more).Definition | Should -Be 'less.exe'
    }

    It 'does nothing when less.exe is not on PATH' {
        Mock -ModuleName $script:Module Get-Command { $null } -ParameterFilter { $Name -eq 'less.exe' }
        Enable-Less -Options '-R' -ReplaceMore
        $env:LESS  | Should -BeNullOrEmpty
        $env:PAGER | Should -BeNullOrEmpty
        Get-Alias more -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }
}
