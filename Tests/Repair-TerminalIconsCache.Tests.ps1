#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
}

Describe 'Repair-TerminalIconsCache' {
    Context 'with a cache directory containing good and corrupt files' {
        BeforeEach {
            $script:Dir = Join-Path ([IO.Path]::GetTempPath()) ("ti-cache-" + [guid]::NewGuid())
            New-Item -ItemType Directory -Path $script:Dir -Force > $null

            # A valid CLIXML icon theme and a valid color theme.
            @{ Name = 'good' } | Export-Clixml -LiteralPath (Join-Path $script:Dir 'good_icon.xml')
            @{ Name = 'good' } | Export-Clixml -LiteralPath (Join-Path $script:Dir 'good_color.xml')
            # Truncated CLIXML — the corruption that wedges Terminal-Icons' import.
            Set-Content -LiteralPath (Join-Path $script:Dir 'bad_icon.xml')  -Value '<Objs><Obj><DCT>'
            Set-Content -LiteralPath (Join-Path $script:Dir 'bad_color.xml') -Value '<Objs><Obj><DCT>'
            # prefs.xml is guarded inside Terminal-Icons; even corrupt it must be left alone.
            Set-Content -LiteralPath (Join-Path $script:Dir 'prefs.xml') -Value 'not xml at all'
        }

        AfterEach {
            Remove-Item -LiteralPath $script:Dir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'removes only the corrupt *_icon.xml / *_color.xml files' {
            & (Get-Module $script:Module) { Repair-TerminalIconsCache -Path $args[0] } $script:Dir
            Test-Path (Join-Path $script:Dir 'bad_icon.xml')  | Should -BeFalse
            Test-Path (Join-Path $script:Dir 'bad_color.xml') | Should -BeFalse
        }

        It 'keeps the valid theme files' {
            & (Get-Module $script:Module) { Repair-TerminalIconsCache -Path $args[0] } $script:Dir
            Test-Path (Join-Path $script:Dir 'good_icon.xml')  | Should -BeTrue
            Test-Path (Join-Path $script:Dir 'good_color.xml') | Should -BeTrue
        }

        It 'leaves prefs.xml alone even when it does not parse' {
            & (Get-Module $script:Module) { Repair-TerminalIconsCache -Path $args[0] } $script:Dir
            Test-Path (Join-Path $script:Dir 'prefs.xml') | Should -BeTrue
        }
    }

    It 'is a safe no-op when the cache directory does not exist' {
        $missing = Join-Path ([IO.Path]::GetTempPath()) ("ti-cache-missing-" + [guid]::NewGuid())
        { & (Get-Module $script:Module) { Repair-TerminalIconsCache -Path $args[0] } $missing } | Should -Not -Throw
    }
}
