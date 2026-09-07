#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
    $script:Rows = & (Get-Module $script:Module) { Get-PwshProfileWiringCatalog }
}

Describe 'Get-PwshProfileWiringCatalog' {
    It 'declares all six properties on every row' {
        # The suite runs under Set-StrictMode -Version Latest, where reading a property a row omitted
        # throws rather than returning $null.
        foreach ($row in $script:Rows) {
            @($row.PSObject.Properties.Name) | Sort-Object |
                Should -Be @('Group', 'Help', 'Label', 'Off', 'On', 'Setting')
        }
    }

    It 'uses only known groups, with non-empty labels and help' {
        foreach ($row in $script:Rows) {
            $row.Group | Should -BeIn @('Replacements', 'Keybindings')
            $row.Label | Should -Not -BeNullOrEmpty
            $row.Help | Should -Not -BeNullOrEmpty
        }
    }

    It 'gives every row a label unique across ALL groups' {
        # Load-bearing, not cosmetic: the Spectre prompt keys selection by the label string and
        # Read-PwshProfileWiringTree maps the result back by label, so a collision across groups would
        # silently toggle the wrong setting.
        @($script:Rows.Label | Sort-Object -Unique).Count | Should -Be $script:Rows.Count
    }

    It 'gives every row distinct On and Off values' {
        # A row whose two sides are equal could never be turned off.
        foreach ($row in $script:Rows) {
            $row.On | Should -Not -Be $row.Off -Because "'$($row.Label)' must be able to express both answers"
        }
    }

    It 'drives only real, wizard-settable schema keys' {
        $wizardKeys = & (Get-Module $script:Module) { @((Get-PwshProfileSettingSchema -Wizard).Name) }
        foreach ($row in $script:Rows) {
            $row.Setting | Should -BeIn $wizardKeys -Because "'$($row.Label)' writes it"
        }
    }

    It 'writes values the schema can actually round-trip' {
        # A Switch row must toggle booleans and a String row strings, or Build would render the value
        # with the wrong strategy and Read would parse it back as something else.
        $schema = & (Get-Module $script:Module) { Get-PwshProfileSettingSchema -Wizard }
        foreach ($row in $script:Rows) {
            $kind = ($schema | Where-Object Name -eq $row.Setting).Kind
            if ($kind -eq 'Switch') {
                $row.On | Should -BeOfType [bool] -Because "'$($row.Setting)' is a Switch"
                $row.Off | Should -BeOfType [bool] -Because "'$($row.Setting)' is a Switch"
            }
            else {
                $row.On | Should -BeOfType [string] -Because "'$($row.Setting)' is a $kind"
                $row.Off | Should -BeOfType [string] -Because "'$($row.Setting)' is a $kind"
            }
        }
    }

    It 'keeps every schema default representable as a checkbox state' {
        # The wizard seeds from Get-PwshProfileDefault, and the tree renders each row as checked or
        # unchecked by comparing against On. A default that matched NEITHER side would open unchecked
        # and then be silently rewritten to Off on submit -- e.g. a ZoxideCommand default of 'j' would
        # quietly become 'z'. This is the invariant that makes the two-value shape safe.
        $default = & (Get-Module $script:Module) { Get-PwshProfileDefault }
        foreach ($row in $script:Rows) {
            $default[$row.Setting] |
                Should -BeIn @($row.On, $row.Off) -Because "'$($row.Label)' must round-trip its own default"
        }
    }

    It 'starts every command takeover off by default, except zoxide' {
        # Nothing should claim one of your existing command names unless you asked for it. zoxide is
        # the deliberate exception, and predates this catalog: its jump command has always defaulted to
        # 'cd', so that row opens checked.
        $default = & (Get-Module $script:Module) { Get-PwshProfileDefault }
        foreach ($row in $script:Rows | Where-Object Setting -ne 'ZoxideCommand') {
            $default[$row.Setting] |
                Should -Be $row.Off -Because "'$($row.Label)' should start unchecked on a clean install"
        }
        $default.ZoxideCommand | Should -Be ($script:Rows | Where-Object Setting -eq 'ZoxideCommand').On
    }

    It 'returns fresh rows on every call' {
        # Read-PwshProfileWiringTree mutates Label, so a memoized catalog would leak render state.
        $first = & (Get-Module $script:Module) { Get-PwshProfileWiringCatalog }
        $second = & (Get-Module $script:Module) { Get-PwshProfileWiringCatalog }
        [object]::ReferenceEquals($first[0], $second[0]) | Should -BeFalse
    }
}

# Read-PwshProfileWiringTree itself is deliberately not unit-tested here. Its body is one Spectre
# MultiSelectionPrompt, which throws outside an interactive terminal, and its only non-Spectre branch
# is guarded on the prompt TYPE being absent -- unreachable in this suite, since importing the module
# loads PwshSpectreConsole. (The feature tree it replaced had the same gap.) What matters about it --
# that every row comes back answered, and that the wizard folds those answers into its settings -- is
# covered through the mock in Tests/Install-PwshProfile.Tests.ps1: see 'folds every checked wiring row
# back into the settings' and 'records an unchecked wiring row as a real no, not a missing key'.
