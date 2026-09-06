#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'

    function New-SettingsFileWithScheme {
        param([string]$Path)
        $seed = [ordered]@{
            profiles = [ordered]@{ defaults = [ordered]@{}; list = @() }
            schemes  = @(
                [ordered]@{ name = 'Campbell'; background = '#0C0C0C' }
                [ordered]@{ name = 'Screw City'; background = '#1a1033' }
            )
        }
        $seed | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $Path -Encoding utf8
    }
}

Describe 'Get-WindowsTerminalSchemeName' {
    BeforeEach {
        $script:Settings = Join-Path $TestDrive 'settings.json'
    }

    It 'returns every scheme name present in settings.json' {
        New-SettingsFileWithScheme -Path $script:Settings
        InModuleScope $script:Module -Parameters @{ Path = $script:Settings } {
            param($Path)
            $names = @(Get-WindowsTerminalSchemeName -SettingsPath $Path)
            $names | Should -Contain 'Campbell'
            $names | Should -Contain 'Screw City'
        }
    }

    It 'returns an empty array, silently, when settings.json does not exist' {
        $missing = Join-Path $TestDrive 'nope.json'
        InModuleScope $script:Module -Parameters @{ Path = $missing } {
            param($Path)
            $names = @(Get-WindowsTerminalSchemeName -SettingsPath $Path 3>&1)
            $names | Should -BeNullOrEmpty
        }
    }

    It 'returns an empty array, silently, when settings.json fails to parse' {
        Set-Content -LiteralPath $script:Settings -Value '{ not valid json' -Encoding utf8
        InModuleScope $script:Module -Parameters @{ Path = $script:Settings } {
            param($Path)
            $names = @(Get-WindowsTerminalSchemeName -SettingsPath $Path 3>&1)
            $names | Should -BeNullOrEmpty
        }
    }

    It 'discovers the path itself when -SettingsPath is omitted' {
        New-SettingsFileWithScheme -Path $script:Settings
        InModuleScope $script:Module -Parameters @{ Path = $script:Settings } {
            param($Path)
            Mock Get-WindowsTerminalSettingsPath { $Path }
            @(Get-WindowsTerminalSchemeName) | Should -Contain 'Campbell'
        }
    }

    It 'returns an empty array when no settings.json can be found' {
        InModuleScope $script:Module {
            Mock Get-WindowsTerminalSettingsPath { $null }
            @(Get-WindowsTerminalSchemeName) | Should -BeNullOrEmpty
        }
    }
}
