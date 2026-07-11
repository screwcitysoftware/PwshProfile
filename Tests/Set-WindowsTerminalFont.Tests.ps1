#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'

    # Seed a settings.json with a profiles block and an unrelated scheme, so we can assert the edit
    # sets profiles.defaults.font.face without clobbering anything else.
    function New-SettingsFile {
        param([string]$Path)
        $seed = [ordered]@{
            '$schema' = 'https://aka.ms/terminal-profiles-schema'
            profiles  = [ordered]@{
                defaults = [ordered]@{}
                list     = @([ordered]@{ name = 'PowerShell'; guid = '{guid}' })
            }
            schemes   = @([ordered]@{ name = 'Campbell'; background = '#0C0C0C'; foreground = '#CCCCCC' })
        }
        $seed | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $Path -Encoding utf8
    }
}

Describe 'Set-WindowsTerminalFont' {
    BeforeEach {
        # $TestDrive is shared across It blocks; clear any .bak a prior test left behind so each
        # test starts from a clean slate.
        $script:Settings = Join-Path $TestDrive 'settings.json'
        Remove-Item -LiteralPath "$script:Settings.bak" -ErrorAction SilentlyContinue
        New-SettingsFile -Path $script:Settings
    }

    It 'sets profiles.defaults.font.face to the default font' {
        Set-WindowsTerminalFont -SettingsPath $script:Settings 6> $null

        $json = Get-Content -LiteralPath $script:Settings -Raw | ConvertFrom-Json
        $json.profiles.defaults.font.face | Should -Be 'MesloLGM Nerd Font'
    }

    It 'honors a custom -FontFace' {
        Set-WindowsTerminalFont -FontFace 'CaskaydiaCove Nerd Font' -SettingsPath $script:Settings 6> $null

        $json = Get-Content -LiteralPath $script:Settings -Raw | ConvertFrom-Json
        $json.profiles.defaults.font.face | Should -Be 'CaskaydiaCove Nerd Font'
    }

    It 'leaves existing schemes untouched' {
        Set-WindowsTerminalFont -SettingsPath $script:Settings 6> $null

        $json = Get-Content -LiteralPath $script:Settings -Raw | ConvertFrom-Json
        @($json.schemes.name) | Should -Contain 'Campbell'
    }

    It 'is idempotent — a re-run just overwrites the face' {
        Set-WindowsTerminalFont -SettingsPath $script:Settings 6> $null
        Set-WindowsTerminalFont -FontFace 'CaskaydiaCove Nerd Font' -SettingsPath $script:Settings 6> $null

        $json = Get-Content -LiteralPath $script:Settings -Raw | ConvertFrom-Json
        $json.profiles.defaults.font.face | Should -Be 'CaskaydiaCove Nerd Font'
    }

    It 'backs up the original to settings.json.bak' {
        Set-WindowsTerminalFont -SettingsPath $script:Settings 6> $null
        Test-Path -LiteralPath "$script:Settings.bak" | Should -BeTrue
    }

    It '-WhatIf writes nothing (no change, no backup)' {
        $before = Get-Content -LiteralPath $script:Settings -Raw
        Set-WindowsTerminalFont -SettingsPath $script:Settings -WhatIf 6> $null

        Get-Content -LiteralPath $script:Settings -Raw | Should -Be $before
        Test-Path -LiteralPath "$script:Settings.bak" | Should -BeFalse
    }

    It 'resolves the default settings path via Get-WindowsTerminalSettingsPath' {
        Mock -ModuleName $script:Module Get-WindowsTerminalSettingsPath { $script:Settings }
        Set-WindowsTerminalFont 6> $null

        Should -Invoke -ModuleName $script:Module Get-WindowsTerminalSettingsPath -Times 1 -Exactly
        $json = Get-Content -LiteralPath $script:Settings -Raw | ConvertFrom-Json
        $json.profiles.defaults.font.face | Should -Be 'MesloLGM Nerd Font'
    }

    It 'warns and changes nothing when no settings.json is found' {
        Mock -ModuleName $script:Module Get-WindowsTerminalSettingsPath { $null }
        $warnings = Set-WindowsTerminalFont 3>&1 6> $null
        "$warnings" | Should -Match 'settings.json not found'
    }
}
