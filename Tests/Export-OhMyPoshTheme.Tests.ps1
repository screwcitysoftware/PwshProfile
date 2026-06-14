#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:BundledTheme = Join-Path $PSScriptRoot '..' 'Assets' 'Themes' 'screwcity.omp.json'
}

Describe 'Export-OhMyPoshTheme' {
    BeforeEach {
        $script:Dest = Join-Path ([System.IO.Path]::GetTempPath()) "sc-export-$([guid]::NewGuid()).omp.json"
    }

    AfterEach {
        Remove-Item -Path $script:Dest -ErrorAction SilentlyContinue
    }

    It 'writes the bundled theme to the destination' {
        Export-OhMyPoshTheme -Path $script:Dest
        Test-Path -Path $script:Dest | Should -BeTrue
        Get-Content -Path $script:Dest -Raw | Should -Be (Get-Content -Path $script:BundledTheme -Raw)
    }

    It 'refuses to overwrite an existing file without -Force' {
        Set-Content -Path $script:Dest -Value 'existing' -NoNewline
        { Export-OhMyPoshTheme -Path $script:Dest -ErrorAction Stop } | Should -Throw
        Get-Content -Path $script:Dest -Raw | Should -Be 'existing'
    }

    It 'overwrites an existing file with -Force' {
        Set-Content -Path $script:Dest -Value 'existing' -NoNewline
        Export-OhMyPoshTheme -Path $script:Dest -Force
        Get-Content -Path $script:Dest -Raw | Should -Be (Get-Content -Path $script:BundledTheme -Raw)
    }
}
