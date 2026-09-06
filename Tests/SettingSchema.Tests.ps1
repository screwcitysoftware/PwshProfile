#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
    $script:Schema = & (Get-Module $script:Module) { Get-PwshProfileSettingSchema }
    $script:WizardSchema = & (Get-Module $script:Module) { Get-PwshProfileSettingSchema -Wizard }
}

Describe 'Get-PwshProfileSettingSchema' {
    Context 'row shape' {
        It 'declares all eight properties on every row' {
            # The suite runs under Set-StrictMode -Version Latest, where reading a property a row
            # omitted throws rather than returning $null. Consumers filter on BrandingKey and Tool
            # across all rows, so a row missing one would break them, not just read as absent.
            foreach ($row in $script:Schema) {
                $names = @($row.PSObject.Properties.Name) | Sort-Object
                $names | Should -Be @('Banner', 'BrandingKey', 'Default', 'Emit', 'Kind', 'Name', 'Neutral', 'Tool')
            }
        }

        It 'uses only known Kind and Emit values' {
            # 'Array' is deliberately not a valid Kind: Read-PwshProfileInstalledSetting's array
            # parsing went away with -Enable, so adding an array row must fail here rather than
            # silently reading back as a scalar.
            foreach ($row in $script:Schema) {
                $row.Name | Should -Not -BeNullOrEmpty
                $row.Kind | Should -BeIn @('String', 'Switch')
                $row.Emit | Should -BeIn @('Scalar', 'Interpolated', 'Switch', 'Custom', 'None')
            }
        }

        It 'types each default to match its Kind' {
            foreach ($row in $script:Schema | Where-Object Kind -eq 'Switch') {
                $row.Default | Should -BeOfType [bool] -Because "'$($row.Name)' is a switch"
            }
        }

        It 'returns fresh rows on every call' {
            # Get-PwshProfileDefault promises a hashtable callers may freely mutate, and the wizard
            # calls .Clone() on it. A memoized schema would hand every caller the same row instances,
            # so a future reference-typed default would be shared state rather than a per-call copy.
            $first = & (Get-Module $script:Module) { Get-PwshProfileSettingSchema }
            $second = & (Get-Module $script:Module) { Get-PwshProfileSettingSchema }
            [object]::ReferenceEquals($first[0], $second[0]) | Should -BeFalse
        }
    }

    Context 'membership' {
        It 'returns exactly the settings a profile can carry under -Wizard' {
            # The deliberate tripwire. Adding a parameter to the schema without deciding whether it
            # reaches a profile fails here, which is the moment to make that call rather than later
            # when a value silently fails to round-trip.
            @($script:WizardSchema.Name) | Sort-Object | Should -Be (@(
                    'BannerAlignment', 'BannerColor', 'BannerFont', 'BannerText', 'BatStyle', 'BatTheme',
                    'CustomTheme', 'FzfGitKeyBindings', 'FzfTabChord', 'LessOptions', 'NoBanner',
                    'ReplaceCat', 'ReplaceHttp', 'ReplaceMore', 'SetPager', 'StepIcon', 'Theme', 'ZoxideCommand'
                ) | Sort-Object)
        }

        It 'defines -Wizard as exactly the emitted rows' {
            # One column, not two. A wizard key must be emitted or it is lost on re-run; a runtime-only
            # key must not be. Two columns could only ever disagree.
            @($script:WizardSchema.Name) | Should -Be @(($script:Schema | Where-Object { $_.Emit -ne 'None' }).Name)
        }

        It 'matches the keys Get-PwshProfileDefault seeds' {
            $defaultKeys = & (Get-Module $script:Module) { @((Get-PwshProfileDefault).Keys) }
            @($script:WizardSchema.Name) | Sort-Object | Should -Be (@($defaultKeys) | Sort-Object)
        }

        It 'reserves Emit Custom for the keys Build places by hand' {
            # Mutually exclusive Theme/CustomTheme, and NoBanner's fixed slot ahead of the scalars it
            # suppresses. Tagging them is what stops a new key silently inheriting a rendering strategy.
            @(($script:Schema | Where-Object Emit -eq 'Custom').Name) |
                Should -Be @('Theme', 'CustomTheme', 'NoBanner')
        }
    }

    Context 'cross-references to the other sources of truth' {
        It 'names only real catalog tokens in Tool' {
            $tokens = & (Get-Module $script:Module) { Get-PwshProfileToolCatalog -Token }
            foreach ($row in $script:Schema | Where-Object Tool) {
                $row.Tool | Should -BeIn $tokens -Because "'$($row.Name)' claims to belong to it"
            }
        }

        It 'names branding members that actually resolve, for every bundled theme' {
            # This is what makes the FdColors -> LsColors mismatch safe: the column names the branding
            # member rather than assuming it equals the setting name, and a typo fails here.
            $themes = & (Get-Module $script:Module) { Get-BundledThemeName }
            foreach ($theme in $themes) {
                $branding = & (Get-Module $script:Module) { param($t) Get-BundledThemeBranding -Name $t } $theme
                foreach ($row in $script:Schema | Where-Object BrandingKey) {
                    $branding[$row.BrandingKey] |
                        Should -Not -BeNullOrEmpty -Because "'$($row.Name)' reads branding member '$($row.BrandingKey)' for theme '$theme'"
                }
            }
        }

        It 'gives every branded profile setting a neutral for the custom-theme path' {
            # A custom theme has no bundled identity, so a branded key needs somewhere to fall back to.
            # Runtime-only branded keys (FdColors/FzfColors) never reach the wizard and are exempt.
            foreach ($row in $script:WizardSchema | Where-Object BrandingKey) {
                $row.Neutral | Should -Not -BeNullOrEmpty -Because "'$($row.Name)' is branded and wizard-settable"
            }
        }

        It 'names only real Initialize-PwshProfile parameters, with matching types' {
            $params = (Get-Command Initialize-PwshProfile).Parameters
            $expected = @{ String = [string]; Switch = [switch] }
            foreach ($row in $script:Schema) {
                $params.ContainsKey($row.Name) |
                    Should -BeTrue -Because "the schema claims '$($row.Name)' is a settable parameter"
                $params[$row.Name].ParameterType |
                    Should -Be $expected[$row.Kind] -Because "'$($row.Name)' is declared Kind '$($row.Kind)'"
            }
        }
    }
}
