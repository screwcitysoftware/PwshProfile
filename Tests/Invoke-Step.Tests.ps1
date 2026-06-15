#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'

    # Fake stand-in for [Spectre.Console.StatusContext]: the spinner renders through
    # AnsiConsole (not PowerShell streams), so the renderer is tested by invoking
    # Invoke-Step's scriptblock with a fake context whose Status setter records every
    # breadcrumb update.
    function New-FakeStatusContext {
        $ctx = [pscustomobject]@{ History = [System.Collections.Generic.List[string]]::new() }
        $ctx | Add-Member -MemberType ScriptProperty -Name Status `
            -Value { $this.History[-1] } `
            -SecondValue { param($value) $this.History.Add($value) }
        return $ctx
    }
}

Describe 'Invoke-Step' {
    BeforeEach {
        # Intercept the spinner: run the scriptblock with a fake context and capture it (and
        # the title) so tests can assert on the recorded breadcrumb history. Summary lines
        # are captured by mocking Write-SpectreHost.
        $script:CapturedContext = $null
        $script:CapturedTitle = $null
        $script:SummaryLines = [System.Collections.Generic.List[string]]::new()
        Mock -ModuleName $script:Module Invoke-SpectreCommandWithStatus {
            $ctx = New-FakeStatusContext
            $script:CapturedContext = $ctx
            $script:CapturedTitle = $Title
            & $ScriptBlock $ctx
        }
        Mock -ModuleName $script:Module Write-SpectreHost {
            $script:SummaryLines.Add($Message)
        }
    }

    # Assertions that include the icon pass it explicitly so the tests don't depend on the
    # default icon value.
    It 'opens the spinner with the step as title and breadcrumb' {
        Invoke-Step 'Sample' { } -Icon '⚡'
        $script:CapturedTitle | Should -Be '⚡ Sample'
        $script:CapturedContext.History[0] | Should -Be '⚡ Sample'
    }

    It 'walks the breadcrumb through nested steps and restores the parent' {
        Invoke-Step 'Outer' { Invoke-Step 'Inner' { } } -Icon '⚡'
        $script:CapturedContext.History | Should -Be @(
            '⚡ Outer'
            '⚡ Outer › Inner'
            '⚡ Outer'
        )
    }

    It 'shows the deep path for multiply nested steps' {
        Invoke-Step 'WinGet' { Invoke-Step 'fnm' { Invoke-Step 'Install' { } } } -Icon '⚡'
        $script:CapturedContext.History | Should -Contain '⚡ WinGet › fnm › Install'
    }

    It 'uses a custom top-level icon as the breadcrumb prefix' {
        Invoke-Step 'Sample' { } -Icon '🔧'
        $script:CapturedContext.History[0] | Should -Be '🔧 Sample'
    }

    It 'opens one spinner per top-level step even with nested children' {
        Invoke-Step 'Outer' {
            Invoke-Step 'One' { }
            Invoke-Step 'Two' { }
        }
        Should -Invoke -ModuleName $script:Module Invoke-SpectreCommandWithStatus -Times 1 -Exactly
    }

    It 'escapes markup brackets in step text' {
        Invoke-Step 'weird [name]' { } -Icon '⚡'
        $script:CapturedContext.History[0] | Should -Be '⚡ weird [[name]]'
    }

    It 'writes one summary line with timing for a top-level step' {
        Invoke-Step 'Sample' { } -Icon '⚡'
        $script:SummaryLines.Count | Should -Be 1
        $script:SummaryLines[0] | Should -Match '^\[yellow\]⚡ \[/\]Sample\[grey\]\.+\[/\] \[yellow\]\[\[\s*\d+ms\]\]\[/\]$'
    }

    It 'writes no summary lines for nested substeps' {
        Invoke-Step 'Outer' {
            Invoke-Step 'One' { }
            Invoke-Step 'Two' { }
        }
        $script:SummaryLines.Count | Should -Be 1
        $script:SummaryLines[0] | Should -Match 'Outer'
    }

    It 'shows a custom icon in the summary line' {
        Invoke-Step 'Sample' { } -Icon '🔧'
        $script:SummaryLines[0] | Should -Match '^\[yellow\]🔧 \[/\]Sample'
    }

    It 'emits nothing to the pipeline' {
        Invoke-Step 'Sample' { 'leak' } | Should -BeNullOrEmpty
    }

    It 're-surfaces a warning raised inside a step after the spinner clears' {
        # The body's warning is captured during the spinner, then replayed via Write-Warning;
        # 3>&1 catches that replayed warning on the outer call.
        $out = Invoke-Step 'Sample' { Write-Warning 'icons failed' } -Icon '⚡' 3>&1
        @($out | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }).Message |
            Should -Contain 'icons failed'
    }

    It 'captures and re-surfaces warnings from nested substeps too' {
        $out = Invoke-Step 'Outer' {
            Invoke-Step 'Inner' { Write-Warning 'nested boom' }
        } -Icon '⚡' 3>&1
        @($out | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }).Message |
            Should -Contain 'nested boom'
    }

    It 'does not leak the captured warning into the success pipeline' {
        # 3>&1 merges warnings into the success stream of the *body*, but they must be filtered
        # out before they reach the top-level step's own pipeline output.
        $out = Invoke-Step 'Sample' { Write-Warning 'noise'; 'leak' } 3>$null
        $out | Should -BeNullOrEmpty
    }

    It 'writes no summary and restores module state after a failing step' {
        { Invoke-Step 'Boom' { throw 'x' } } | Should -Throw 'x'
        Should -Invoke -ModuleName $script:Module Write-SpectreHost -Times 0 -Exactly
        InModuleScope $script:Module { $script:StepStatusContext } | Should -BeNullOrEmpty
        InModuleScope $script:Module { $script:StepPath.Count } | Should -Be 0
    }
}

Describe 'Invoke-Step (PwshSpectreConsole unavailable)' {
    BeforeEach {
        Mock -ModuleName $script:Module Get-Command { $null } `
            -ParameterFilter { $Name -eq 'Invoke-SpectreCommandWithStatus' }
        Mock -ModuleName $script:Module Invoke-SpectreCommandWithStatus { }
        Mock -ModuleName $script:Module Write-SpectreHost { }
    }

    It 'still runs the step body, silently' {
        $script:Ran = $false
        Invoke-Step 'Sample' { $script:Ran = $true }
        $script:Ran | Should -BeTrue
        Should -Invoke -ModuleName $script:Module Invoke-SpectreCommandWithStatus -Times 0 -Exactly
        Should -Invoke -ModuleName $script:Module Write-SpectreHost -Times 0 -Exactly
    }

    It 'runs nested steps and emits nothing to the pipeline' {
        $script:Inner = $false
        $out = Invoke-Step 'Outer' { Invoke-Step 'Inner' { $script:Inner = $true; 'leak' } }
        $script:Inner | Should -BeTrue
        $out | Should -BeNullOrEmpty
    }
}
