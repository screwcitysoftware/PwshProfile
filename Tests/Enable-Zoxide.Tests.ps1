#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
}

Describe 'Enable-Zoxide' {
    BeforeEach {
        # Run each substep body inline (no spinner) and never touch winget. Invoke-InGlobalScope is
        # NOT mocked — the hook script must actually run so it registers the LocationChangedAction,
        # and a real Set-Location must fire it (the path that actually matters at the prompt).
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Mock -ModuleName $script:Module Install-WingetPackageSafe { }
        # zoxide.exe is "present" so Initialize runs.
        Mock -ModuleName $script:Module Get-Command { $true } -ParameterFilter { $Name -eq 'zoxide.exe' }

        # A global `zoxide` shim. `zoxide add` records the invocation and emits nothing; `zoxide init`
        # must emit a non-empty string because Invoke-InGlobalScope rejects an empty -Expression. The
        # emitted init text is harmless (a comment) — the cd/cdi aliases aren't needed for these tests.
        $global:ZoxideAddCalls = 0
        function global:zoxide {
            if ($args -contains 'add') { $global:ZoxideAddCalls++; return }
            '# zoxide stub'
        }

        # The location hook and current directory are process-global; snapshot and reset so each test
        # is isolated, and clear any leftover hook globals from a prior run.
        $script:savedLoc = $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction
        $script:savedPwd = $PWD
        $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction = $null
        Remove-Variable -Name __zoxide_loc_hooked, __zoxide_loc_base -Scope Global -ErrorAction SilentlyContinue

        # An isolated temp tree with two real directories to move between.
        $script:testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("zoxidetest_" + [guid]::NewGuid().ToString('N'))
        $script:dirA = Join-Path $script:testRoot 'a'
        $script:dirB = Join-Path $script:testRoot 'b'
        New-Item -ItemType Directory -Path $script:dirA -Force | Out-Null
        New-Item -ItemType Directory -Path $script:dirB -Force | Out-Null
    }

    AfterEach {
        $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction = $script:savedLoc
        Set-Location $script:savedPwd
        Remove-Item -LiteralPath $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
        # Remove the global function shim. The Function: provider does NOT honor a 'global:' scope
        # qualifier in the path, so use the bare name — it resolves to the global function and removes
        # it, unshadowing the cmdlet. Done here (not inline) so a shim never leaks into later test files.
        Remove-Item Function:zoxide -ErrorAction SilentlyContinue
        Remove-Variable -Name ZoxideAddCalls, BaseRan, __zoxide_loc_hooked, __zoxide_loc_base -Scope Global -ErrorAction SilentlyContinue
    }

    It 'registers a location hook' {
        Enable-Zoxide
        $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction | Should -Not -BeNullOrEmpty
    }

    It 'runs zoxide add when changing into a filesystem directory' {
        Enable-Zoxide
        Set-Location $script:dirA
        $global:ZoxideAddCalls | Should -Be 1
    }

    It 'chains a pre-existing LocationChangedAction' {
        $global:BaseRan = 0
        $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction = { $global:BaseRan++ }

        Enable-Zoxide
        Set-Location $script:dirA

        $global:BaseRan        | Should -Be 1
        $global:ZoxideAddCalls | Should -Be 1
    }

    It 'is reload-safe: re-running re-installs without stacking zoxide add calls' {
        Enable-Zoxide
        Enable-Zoxide      # simulates Import-Module -Force; . $PROFILE in a live session
        Set-Location $script:dirA
        $global:ZoxideAddCalls | Should -Be 1
    }
}
