#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'

    # Seed a settings.json with an unrelated scheme and a profiles block, so we can assert the
    # edit adds without clobbering and that -SetDefault wires profiles.defaults.colorScheme.
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

Describe 'Install-WindowsTerminalScheme' {
    BeforeEach {
        # $TestDrive is shared across It blocks; clear any .bak a prior test left behind so each
        # test starts from a clean slate.
        $script:Settings = Join-Path $TestDrive 'settings.json'
        Remove-Item -LiteralPath "$script:Settings.bak" -ErrorAction SilentlyContinue
        New-SettingsFile -Path $script:Settings
    }

    It 'adds the theme scheme without removing existing schemes' {
        Install-WindowsTerminalScheme -Theme screwcity -SettingsPath $script:Settings 6> $null

        $json = Get-Content -LiteralPath $script:Settings -Raw | ConvertFrom-Json
        $names = @($json.schemes.name)
        $names | Should -Contain 'Campbell'
        $names | Should -Contain 'Screw City'
    }

    It 'writes a complete scheme (bg/fg + 16 ANSI keys)' {
        Install-WindowsTerminalScheme -Theme forestcity -SettingsPath $script:Settings 6> $null

        $json = Get-Content -LiteralPath $script:Settings -Raw | ConvertFrom-Json
        $scheme = $json.schemes | Where-Object { $_.name -eq 'Forest City' }
        $scheme | Should -Not -BeNullOrEmpty
        foreach ($key in 'background', 'foreground', 'cursorColor', 'selectionBackground',
            'black', 'red', 'green', 'yellow', 'blue', 'purple', 'cyan', 'white',
            'brightBlack', 'brightRed', 'brightGreen', 'brightYellow', 'brightBlue',
            'brightPurple', 'brightCyan', 'brightWhite') {
            $scheme.$key | Should -Match '^#[0-9a-fA-F]{6}$' -Because "scheme should define $key"
        }
    }

    It 'is idempotent — a re-run replaces rather than duplicates' {
        Install-WindowsTerminalScheme -Theme screwcity -SettingsPath $script:Settings 6> $null
        Install-WindowsTerminalScheme -Theme screwcity -SettingsPath $script:Settings 6> $null

        $json = Get-Content -LiteralPath $script:Settings -Raw | ConvertFrom-Json
        @($json.schemes | Where-Object { $_.name -eq 'Screw City' }).Count | Should -Be 1
    }

    It 'backs up the original to settings.json.bak' {
        Install-WindowsTerminalScheme -Theme screwcity -SettingsPath $script:Settings 6> $null
        Test-Path -LiteralPath "$script:Settings.bak" | Should -BeTrue
    }

    It '-SetDefault wires profiles.defaults.colorScheme' {
        Install-WindowsTerminalScheme -Theme screwcity -SettingsPath $script:Settings -SetDefault 6> $null

        $json = Get-Content -LiteralPath $script:Settings -Raw | ConvertFrom-Json
        $json.profiles.defaults.colorScheme | Should -Be 'Screw City'
    }

    It 'without -SetDefault leaves profiles.defaults.colorScheme unset' {
        Install-WindowsTerminalScheme -Theme screwcity -SettingsPath $script:Settings 6> $null

        $json = Get-Content -LiteralPath $script:Settings -Raw | ConvertFrom-Json
        $json.profiles.defaults.PSObject.Properties['colorScheme'] | Should -BeNullOrEmpty
    }

    It '-WhatIf writes nothing (no change, no backup)' {
        $before = Get-Content -LiteralPath $script:Settings -Raw
        Install-WindowsTerminalScheme -Theme screwcity -SettingsPath $script:Settings -WhatIf 6> $null

        Get-Content -LiteralPath $script:Settings -Raw | Should -Be $before
        Test-Path -LiteralPath "$script:Settings.bak" | Should -BeFalse
    }

    It 'resolves the default settings path via Get-WindowsTerminalSettingsPath' {
        Mock -ModuleName $script:Module Get-WindowsTerminalSettingsPath { $script:Settings }
        Install-WindowsTerminalScheme -Theme screwcity 6> $null

        Should -Invoke -ModuleName $script:Module Get-WindowsTerminalSettingsPath -Times 1 -Exactly
        $json = Get-Content -LiteralPath $script:Settings -Raw | ConvertFrom-Json
        @($json.schemes.name) | Should -Contain 'Screw City'
    }

    It 'warns and changes nothing when no settings.json is found' {
        Mock -ModuleName $script:Module Get-WindowsTerminalSettingsPath { $null }
        $warnings = Install-WindowsTerminalScheme -Theme screwcity 3>&1 6> $null
        "$warnings" | Should -Match 'settings.json not found'
    }
}
