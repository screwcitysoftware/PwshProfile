#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'

    $script:Open = '# >>> ScrewCitySoftware.PwshProfile bootstrap >>>'
    $script:Close = '# <<< ScrewCitySoftware.PwshProfile bootstrap <<<'
    $script:Block = @(
        $script:Open
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

        # Read-PwshProfileUninstallTree's body is one Spectre MultiSelectionPrompt, which throws
        # outside a real interactive terminal. Every test here calls Uninstall-PwshProfile, which
        # would otherwise reach it (PwshSpectreConsole is loaded, so the interactive-probe is $true
        # under Pester) — default it to "nothing selected" so existing behavior is unaffected; tests
        # of the new removal step override this per-test.
        Mock -ModuleName $script:Module Read-PwshProfileUninstallTree { @() }
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

    It 'performs no removals and reports an empty Uninstalled list when nothing is selected' {
        Set-Content -LiteralPath $script:Dest -NoNewline -Value $script:Block
        Mock -ModuleName $script:Module Uninstall-WingetPackageSafe { $true }
        Mock -ModuleName $script:Module Uninstall-ModuleSafe { $true }
        Mock -ModuleName $script:Module Uninstall-WindowsTerminalScheme { }

        $r = Uninstall-PwshProfile -Path $script:Dest -PassThru

        $r.Uninstalled | Should -BeNullOrEmpty
        Should -Invoke -ModuleName $script:Module Uninstall-WingetPackageSafe -Times 0 -Exactly
        Should -Invoke -ModuleName $script:Module Uninstall-ModuleSafe -Times 0 -Exactly
        Should -Invoke -ModuleName $script:Module Uninstall-WindowsTerminalScheme -Times 0 -Exactly
    }

    It 'removes only the checked items and reports each one in -PassThru' {
        Set-Content -LiteralPath $script:Dest -NoNewline -Value $script:Block
        Mock -ModuleName $script:Module Read-PwshProfileUninstallTree {
            @(
                [pscustomobject]@{ Group = 'WinGet Tools'; Label = 'zoxide (smart cd)'; Kind = 'Tool'
                    Id = 'ajeetdsouza.zoxide'; Exe = 'zoxide.exe'; Name = $null; Theme = $null }
                [pscustomobject]@{ Group = 'Modules'; Label = 'PSFzf (fzf key bindings)'; Kind = 'Module'
                    Id = $null; Exe = $null; Name = 'PSFzf'; Theme = $null }
                [pscustomobject]@{ Group = 'Windows Terminal'; Label = "Windows Terminal color scheme 'Screw City'"
                    Kind = 'TerminalScheme'; Id = $null; Exe = $null; Name = $null; Theme = 'screwcity' }
            )
        }
        Mock -ModuleName $script:Module Uninstall-WingetPackageSafe { $true }
        Mock -ModuleName $script:Module Uninstall-ModuleSafe { $true }
        Mock -ModuleName $script:Module Uninstall-WindowsTerminalScheme { }

        $r = Uninstall-PwshProfile -Path $script:Dest -PassThru

        Should -Invoke -ModuleName $script:Module Uninstall-WingetPackageSafe -Times 1 -Exactly `
            -ParameterFilter { $Id -eq 'ajeetdsouza.zoxide' -and $Exe -eq 'zoxide.exe' }
        Should -Invoke -ModuleName $script:Module Uninstall-ModuleSafe -Times 1 -Exactly `
            -ParameterFilter { $Name -eq 'PSFzf' }
        Should -Invoke -ModuleName $script:Module Uninstall-WindowsTerminalScheme -Times 1 -Exactly `
            -ParameterFilter { $Theme -eq 'screwcity' }
        $r.Uninstalled.Count | Should -Be 3
        @($r.Uninstalled | Where-Object Removed).Count | Should -Be 3
    }

    It 'reports a failed removal as Removed = $false without stopping the rest' {
        Set-Content -LiteralPath $script:Dest -NoNewline -Value $script:Block
        Mock -ModuleName $script:Module Read-PwshProfileUninstallTree {
            @(
                [pscustomobject]@{ Group = 'WinGet Tools'; Label = 'zoxide (smart cd)'; Kind = 'Tool'
                    Id = 'ajeetdsouza.zoxide'; Exe = 'zoxide.exe'; Name = $null; Theme = $null }
                [pscustomobject]@{ Group = 'Modules'; Label = 'PSFzf (fzf key bindings)'; Kind = 'Module'
                    Id = $null; Exe = $null; Name = 'PSFzf'; Theme = $null }
            )
        }
        Mock -ModuleName $script:Module Uninstall-WingetPackageSafe { $false }
        Mock -ModuleName $script:Module Uninstall-ModuleSafe { $true }

        $r = Uninstall-PwshProfile -Path $script:Dest -PassThru

        ($r.Uninstalled | Where-Object Label -eq 'zoxide (smart cd)').Removed | Should -BeFalse
        ($r.Uninstalled | Where-Object Label -eq 'PSFzf (fzf key bindings)').Removed | Should -BeTrue
    }

    It '-WhatIf performs no selected removals' {
        Set-Content -LiteralPath $script:Dest -NoNewline -Value $script:Block
        Mock -ModuleName $script:Module Read-PwshProfileUninstallTree {
            @([pscustomobject]@{ Group = 'WinGet Tools'; Label = 'zoxide (smart cd)'; Kind = 'Tool'
                    Id = 'ajeetdsouza.zoxide'; Exe = 'zoxide.exe'; Name = $null; Theme = $null })
        }
        Mock -ModuleName $script:Module Uninstall-WingetPackageSafe { $true }

        Uninstall-PwshProfile -Path $script:Dest -WhatIf | Out-Null

        Should -Invoke -ModuleName $script:Module Uninstall-WingetPackageSafe -Times 0 -Exactly
    }

    It 'round-trips: Install then Uninstall restores the original user content' {
        Mock -ModuleName $script:Module Write-Figlet { }
        # Install-PwshProfile ends by offering to reload the profile; decline it and stub the reload,
        # or this reaches a real Spectre prompt and dot-sources the temp file into the test session.
        Mock -ModuleName $script:Module Read-SpectreConfirm { $false } -RemoveParameterType 'Color'
        Mock -ModuleName $script:Module Invoke-InGlobalScope { }
        Mock -ModuleName $script:Module Invoke-PwshProfileWizard {
            @{
                BannerText = 'Screw City'; BannerColor = '#c9aaff'; BannerAlignment = 'Left'
                BannerFont = 'ANSIShadow'; StepIcon = ':nut_and_bolt:'; ZoxideCommand = 'cd'
                NoBanner = $false; NerdFont = $null
            }
        }
        Set-Content -LiteralPath $script:Dest -NoNewline -Value "Write-Host 'mine'"
        Install-PwshProfile -Path $script:Dest | Out-Null
        (Get-Content -LiteralPath $script:Dest -Raw) | Should -Match '# >>>'   # block was added
        Uninstall-PwshProfile -Path $script:Dest | Out-Null
        (Get-Content -LiteralPath $script:Dest -Raw) | Should -BeExactly "Write-Host 'mine'"
    }
}
