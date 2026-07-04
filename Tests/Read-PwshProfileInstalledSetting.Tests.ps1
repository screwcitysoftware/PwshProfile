#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
    $script:Dest = Join-Path ([System.IO.Path]::GetTempPath()) "sc-installed-$([guid]::NewGuid()).ps1"

    # Write a generated bootstrap for the given settings-mutator, then return the parsed result.
    function script:ParseBuilt {
        param([scriptblock]$Mutate)
        & (Get-Module $script:Module) {
            param($dest, $mutate)
            $s = Get-PwshProfileDefault
            & $mutate $s
            $block = Get-PwshProfileBlock -InitializeCall (Build-PwshProfileInitializeCall -Setting $s)
            Set-Content -LiteralPath $dest -Value $block -Encoding utf8 -NoNewline
            Read-PwshProfileInstalledSetting -Path $dest
        } $script:Dest $Mutate
    }

    $script:CatalogTokens = & (Get-Module $script:Module) { Get-PwshProfileToolCatalog -Token }
}

Describe 'Read-PwshProfileInstalledSetting' {
    AfterEach {
        Remove-Item -LiteralPath $script:Dest -ErrorAction SilentlyContinue
    }

    It 'round-trips a generated -Enable block back into settings + snapshot' {
        $parsed = script:ParseBuilt {
            param($s)
            $s.Theme = 'forestcity'; $s.Enable = @('Zoxide', 'Bat'); $s.ReplaceCat = $true; $s.NoBanner = $true
        }
        $parsed | Should -Not -BeNullOrEmpty
        $parsed.Settings.Theme | Should -Be 'forestcity'
        $parsed.Settings.NoBanner | Should -BeTrue
        $parsed.Settings.ReplaceCat | Should -BeTrue
        @($parsed.Settings.Enable) | Should -Be @('Zoxide', 'Bat')
        @($parsed.ToolSnapshot) | Should -Be @($script:CatalogTokens)
    }

    It 'round-trips fzf keybinding tuning (a bare -FzfGitKeyBindings and a custom -FzfTabChord)' {
        $parsed = script:ParseBuilt {
            param($s)
            $s.Enable = @('Fzf'); $s.FzfGitKeyBindings = $true; $s.FzfTabChord = 'Ctrl+j'
        }
        # The bare opt-in flag must parse back to $true.
        $parsed.Settings.FzfGitKeyBindings | Should -BeTrue
        $parsed.Settings.FzfTabChord | Should -Be 'Ctrl+j'
    }

    It 'omits the fzf keybinding keys when left at defaults (git chords off)' {
        $parsed = script:ParseBuilt { param($s) $s.Enable = @('Fzf') }
        $parsed.Settings.ContainsKey('FzfGitKeyBindings') | Should -BeFalse
        $parsed.Settings.ContainsKey('FzfTabChord') | Should -BeFalse
    }

    It 'round-trips an -EnableAll block (no Enable key, EnableAll set)' {
        $parsed = script:ParseBuilt { param($s) $s.EnableAll = $true }
        $parsed.Settings.EnableAll | Should -BeTrue
        $parsed.Settings.ContainsKey('Enable') | Should -BeFalse
    }

    It 'parses an empty -Enable @() block as an empty selection' {
        $parsed = script:ParseBuilt { param($s) $s.Enable = @() }
        @($parsed.Settings.Enable).Count | Should -Be 0
    }

    It 'returns $null when the file has no managed block' {
        Set-Content -LiteralPath $script:Dest -Value "Write-Host 'hi'" -Encoding utf8
        $parsed = & (Get-Module $script:Module) { param($d) Read-PwshProfileInstalledSetting -Path $d } $script:Dest
        $parsed | Should -BeNullOrEmpty
    }

    It 'returns $null for a missing file (no throw)' {
        $parsed = & (Get-Module $script:Module) { Read-PwshProfileInstalledSetting -Path 'X:\does\not\exist.ps1' }
        $parsed | Should -BeNullOrEmpty
    }
}
