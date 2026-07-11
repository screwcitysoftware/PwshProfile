#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'

    # Seed with the Screw City scheme already present plus an unrelated scheme to confirm it survives.
    function New-SettingsFileWithScheme {
        param([string]$Path, [switch]$Referenced)
        $defaults = if ($Referenced) { [ordered]@{ colorScheme = 'Screw City' } } else { [ordered]@{} }
        $seed = [ordered]@{
            profiles = [ordered]@{ defaults = $defaults; list = @() }
            schemes  = @(
                [ordered]@{ name = 'Campbell'; background = '#0C0C0C' }
                [ordered]@{ name = 'Screw City'; background = '#1a1033' }
            )
        }
        $seed | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $Path -Encoding utf8
    }
}

Describe 'Uninstall-WindowsTerminalScheme' {
    BeforeEach {
        # $TestDrive is shared across It blocks; clear any .bak a prior test left behind.
        $script:Settings = Join-Path $TestDrive 'settings.json'
        Remove-Item -LiteralPath "$script:Settings.bak" -ErrorAction SilentlyContinue
    }

    It 'removes the matching scheme and leaves others intact' {
        New-SettingsFileWithScheme -Path $script:Settings
        Uninstall-WindowsTerminalScheme -Theme screwcity -SettingsPath $script:Settings 6> $null

        $json = Get-Content -LiteralPath $script:Settings -Raw | ConvertFrom-Json
        $names = @($json.schemes.name)
        $names | Should -Not -Contain 'Screw City'
        $names | Should -Contain 'Campbell'
    }

    It 'backs up the original to settings.json.bak' {
        New-SettingsFileWithScheme -Path $script:Settings
        Uninstall-WindowsTerminalScheme -Theme screwcity -SettingsPath $script:Settings 6> $null
        Test-Path -LiteralPath "$script:Settings.bak" | Should -BeTrue
    }

    It 'warns when the scheme is not present' {
        New-SettingsFileWithScheme -Path $script:Settings
        $warnings = Uninstall-WindowsTerminalScheme -Theme forestcity -SettingsPath $script:Settings 3>&1 6> $null
        "$warnings" | Should -Match "no color scheme named 'Forest City'"
    }

    It 'warns when the removed scheme is still referenced as an active colorScheme' {
        New-SettingsFileWithScheme -Path $script:Settings -Referenced
        $warnings = Uninstall-WindowsTerminalScheme -Theme screwcity -SettingsPath $script:Settings 3>&1 6> $null
        "$warnings" | Should -Match 'still set as an active colorScheme'
    }

    It '-WhatIf writes nothing' {
        New-SettingsFileWithScheme -Path $script:Settings
        $before = Get-Content -LiteralPath $script:Settings -Raw
        Uninstall-WindowsTerminalScheme -Theme screwcity -SettingsPath $script:Settings -WhatIf 6> $null

        Get-Content -LiteralPath $script:Settings -Raw | Should -Be $before
        Test-Path -LiteralPath "$script:Settings.bak" | Should -BeFalse
    }

    It 'warns and changes nothing when no settings.json is found' {
        Mock -ModuleName $script:Module Get-WindowsTerminalSettingsPath { $null }
        $warnings = Uninstall-WindowsTerminalScheme -Theme screwcity 3>&1 6> $null
        "$warnings" | Should -Match 'settings.json not found'
    }
}
