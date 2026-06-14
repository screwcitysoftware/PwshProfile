#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'

    $script:Open = '# >>> ScrewCitySoftware.PwshProfile bootstrap >>>'
    $script:Close = '# <<< ScrewCitySoftware.PwshProfile bootstrap <<<'
    $script:Block = @(
        $script:Open
        'Import-Module ScrewCitySoftware.PwshProfile'
        ''
        'Initialize-PwshProfile'
        $script:Close
    ) -join [Environment]::NewLine
}

Describe 'Uninstall-PwshProfile' {
    BeforeEach {
        $script:Dir = Join-Path ([System.IO.Path]::GetTempPath()) ('sc-prof-' + [guid]::NewGuid())
        $script:Dest = Join-Path $script:Dir 'profile.ps1'
        New-Item -ItemType Directory -Path $script:Dir | Out-Null

        # Keep the optional summary panel quiet and binding-safe during tests.
        Mock -ModuleName $script:Module Format-SpectrePanel { } -RemoveParameterType 'Color'
        Mock -ModuleName $script:Module Write-SpectreHost { }
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:Dir) { Remove-Item -LiteralPath $script:Dir -Recurse -Force }
    }

    It 'removes the managed block and preserves surrounding content' {
        $nl = [Environment]::NewLine
        Set-Content -LiteralPath $script:Dest -NoNewline -Value ($script:Block + $nl + $nl + "Write-Host 'mine'")
        $r = Uninstall-PwshProfile -Path $script:Dest -PassThru
        $r.Action | Should -Be 'Removed'
        $r.Changed | Should -BeTrue
        $c = Get-Content -LiteralPath $script:Dest -Raw
        $c | Should -Not -Match '# >>>'
        $c | Should -Match "Write-Host 'mine'"
    }

    It 'empties a file that contained only the managed block' {
        $nl = [Environment]::NewLine
        Set-Content -LiteralPath $script:Dest -NoNewline -Value ($script:Block + $nl)
        Uninstall-PwshProfile -Path $script:Dest | Out-Null
        (Get-Content -LiteralPath $script:Dest -Raw) | Should -BeNullOrEmpty
    }

    It 'reports NotInstalled and changes nothing when there is no block' {
        Set-Content -LiteralPath $script:Dest -NoNewline -Value "Write-Host 'hi'"
        $r = Uninstall-PwshProfile -Path $script:Dest -PassThru
        $r.Action | Should -Be 'NotInstalled'
        $r.Changed | Should -BeFalse
        (Get-Content -LiteralPath $script:Dest -Raw) | Should -BeExactly "Write-Host 'hi'"
    }

    It 'leaves a hand-written bare import untouched' {
        Set-Content -LiteralPath $script:Dest -NoNewline -Value 'Import-Module ScrewCitySoftware.PwshProfile'
        $r = Uninstall-PwshProfile -Path $script:Dest -PassThru
        $r.Action | Should -Be 'NotInstalled'
        $r.Changed | Should -BeFalse
        (Get-Content -LiteralPath $script:Dest -Raw) | Should -BeExactly 'Import-Module ScrewCitySoftware.PwshProfile'
    }

    It 'reports NotInstalled (no throw) when the file does not exist' {
        $missing = Join-Path $script:Dir 'nope.ps1'
        $r = Uninstall-PwshProfile -Path $missing -PassThru
        $r.Action | Should -Be 'NotInstalled'
        $r.Changed | Should -BeFalse
        Test-Path -LiteralPath $missing | Should -BeFalse
    }

    It 'makes no change under -WhatIf' {
        Set-Content -LiteralPath $script:Dest -NoNewline -Value $script:Block
        Uninstall-PwshProfile -Path $script:Dest -WhatIf | Out-Null
        (Get-Content -LiteralPath $script:Dest -Raw) | Should -Match '# >>>'
    }

    It 'throws when the path is an existing directory' {
        { Uninstall-PwshProfile -Path $script:Dir } | Should -Throw '*is a directory*'
    }

    It 'returns nothing by default' {
        Set-Content -LiteralPath $script:Dest -NoNewline -Value $script:Block
        Uninstall-PwshProfile -Path $script:Dest | Should -BeNullOrEmpty
    }

    It 'round-trips: Install then Uninstall restores the original user content' {
        Mock -ModuleName $script:Module Write-Figlet { }
        Mock -ModuleName $script:Module Invoke-PwshProfileWizard {
            @{
                BannerText = 'Screw City'; BannerColor = '#c9aaff'; BannerAlignment = 'Left'
                BannerFont = 'ANSIShadow'; StepIcon = ':nut_and_bolt:'; ZoxideCommand = 'cd'
                Skip = @(); SkipSection = @(); NerdFont = $null
            }
        }
        Set-Content -LiteralPath $script:Dest -NoNewline -Value "Write-Host 'mine'"
        Install-PwshProfile -Path $script:Dest | Out-Null
        (Get-Content -LiteralPath $script:Dest -Raw) | Should -Match '# >>>'   # block was added
        Uninstall-PwshProfile -Path $script:Dest | Out-Null
        (Get-Content -LiteralPath $script:Dest -Raw) | Should -BeExactly "Write-Host 'mine'"
    }
}
