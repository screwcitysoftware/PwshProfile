#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:BundledTheme = Join-Path $PSScriptRoot '..' 'Assets' 'Themes' 'screwcity.omp.json'
    $script:ForestTheme = Join-Path $PSScriptRoot '..' 'Assets' 'Themes' 'forestcity.omp.json'
}

Describe 'Get-OhMyPoshTheme' {
    It 'emits the bundled screwcity theme JSON by default' {
        $content = Get-OhMyPoshTheme
        $content | Should -Not -BeNullOrEmpty
        $content | Should -Be (Get-Content -Path $script:BundledTheme -Raw)
    }

    It 'emits the named theme JSON with -Theme' {
        Get-OhMyPoshTheme -Theme forestcity | Should -Be (Get-Content -Path $script:ForestTheme -Raw)
    }

    It 'rejects an unknown theme name' {
        { Get-OhMyPoshTheme -Theme nope } | Should -Throw
    }
}
