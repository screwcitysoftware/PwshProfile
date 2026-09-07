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

    It 'sets $env:LESS and takes over nothing by default' {
        Mock -ModuleName $script:Module Test-CommandAvailable { $true } -ParameterFilter { $Name -eq 'less.exe' }
        Enable-Less -Options '-R'
        $env:LESS  | Should -Be '-R'
        $env:PAGER | Should -BeNullOrEmpty
        Get-Alias more -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'sets $env:PAGER under -SetPager without touching the more command' {
        # The two halves are independent: this is the one that redirects `help`, git, delta and gh.
        Mock -ModuleName $script:Module Test-CommandAvailable { $true } -ParameterFilter { $Name -eq 'less.exe' }
        Enable-Less -SetPager
        $env:PAGER | Should -Be 'less'
        Get-Alias more -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'aliases more -> less under -ReplaceMore without touching $env:PAGER' {
        # The other half. `help` invokes the literal string more.com, so this alias alone does NOT
        # redirect it -- which is exactly why these are two switches rather than one.
        Mock -ModuleName $script:Module Test-CommandAvailable { $true } -ParameterFilter { $Name -eq 'less.exe' }
        Enable-Less -ReplaceMore
        (Get-Alias more).Definition | Should -Be 'less.exe'
        $env:PAGER | Should -BeNullOrEmpty
    }

    It 'applies both when both are supplied' {
        Mock -ModuleName $script:Module Test-CommandAvailable { $true } -ParameterFilter { $Name -eq 'less.exe' }
        Enable-Less -SetPager -ReplaceMore
        $env:PAGER | Should -Be 'less'
        (Get-Alias more).Definition | Should -Be 'less.exe'
    }

    It 'does nothing when less.exe is not on PATH' {
        Mock -ModuleName $script:Module Test-CommandAvailable { $null } -ParameterFilter { $Name -eq 'less.exe' }
        Enable-Less -Options '-R' -SetPager -ReplaceMore
        $env:LESS  | Should -BeNullOrEmpty
        $env:PAGER | Should -BeNullOrEmpty
        Get-Alias more -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }
}
