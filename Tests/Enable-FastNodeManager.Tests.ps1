#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
}

Describe 'Enable-FastNodeManager' {
    BeforeEach {
        # Run each substep body inline (no spinner) and never touch winget. Invoke-InGlobalScope is
        # NOT mocked — the hook script must actually run so it registers the LocationChangedAction,
        # and a real Set-Location must fire it (the path that actually matters at the prompt).
        Mock -ModuleName $script:Module Invoke-Step { & $ScriptBlock }
        Mock -ModuleName $script:Module Install-WingetPackageSafe { }
        # fnm.exe is "present" so Initialize runs; zoxide is deliberately NOT involved (the hook must
        # not depend on it).
        Mock -ModuleName $script:Module Get-Command { $true } -ParameterFilter { $Name -eq 'fnm.exe' }

        # A global `fnm` shim. `fnm use` records the invocation and emits nothing, so the hook's
        # `| Out-Host` produces no stray output here. `fnm env`/`completions` must emit a non-empty
        # string (a harmless comment) because Invoke-InGlobalScope rejects an empty -Expression.
        $global:FnmUseCalls = 0
        function global:fnm {
            if ($args -contains 'use') { $global:FnmUseCalls++; return }
            '# fnm stub'
        }

        # The location hook and current directory are process-global; snapshot and reset so each test
        # is isolated, and clear any leftover hook globals from a prior run.
        $script:savedLoc = $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction
        $script:savedPwd = $PWD
        $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction = $null
        Remove-Variable -Name __fnm_loc_hooked, __fnm_loc_base -Scope Global -ErrorAction SilentlyContinue

        # An isolated temp tree with two real directories to move between: one IS a Node project
        # (carries a .node-version file), one is not. The hook runs `fnm use` on every filesystem
        # change regardless, but keeping both lets tests exercise project and non-project moves.
        $script:testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("fnmtest_" + [guid]::NewGuid().ToString('N'))
        $script:nodeDir  = Join-Path $script:testRoot 'project'
        $script:plainDir = Join-Path $script:testRoot 'plain'
        New-Item -ItemType Directory -Path $script:nodeDir  -Force | Out-Null
        New-Item -ItemType Directory -Path $script:plainDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:nodeDir '.node-version') -Value 'v20.0.0'
    }

    AfterEach {
        $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction = $script:savedLoc
        Set-Location $script:savedPwd
        Remove-Item -LiteralPath $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
        # Remove any global function shims the tests defined. The Function: provider does NOT honor a
        # 'global:' scope qualifier in the path (Remove-Item Function:global:X is a silent no-op), so
        # use the bare name — it resolves to the global function and removes it, unshadowing the cmdlet.
        # Done here (not inline) so a shim never leaks into later test files even if a test throws —
        # a leaked Out-Host reading the cleared $global:OutHostHits breaks every later test under
        # Set-StrictMode -Version Latest (how CI runs the suite).
        Remove-Item Function:fnm, Function:Out-Host -ErrorAction SilentlyContinue
        Remove-Variable -Name FnmUseCalls, OutHostHits, BaseRan, __fnm_loc_hooked, __fnm_loc_base -Scope Global -ErrorAction SilentlyContinue
    }

    It 'registers a location hook even when zoxide is absent' {
        Enable-FastNodeManager
        $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction | Should -Not -BeNullOrEmpty
    }

    It 'runs fnm use when changing into a Node project (version file present)' {
        Enable-FastNodeManager
        Set-Location $script:nodeDir
        $global:FnmUseCalls | Should -Be 1
    }

    It 'runs fnm use on any directory change (auto-reverts outside a Node project)' {
        # There is no version-file gate: fnm use runs on every filesystem change and fnm itself
        # resolves the version (reverting to the default outside a Node project, silent if unchanged).
        Enable-FastNodeManager
        Set-Location $script:plainDir
        $global:FnmUseCalls | Should -Be 1
    }

    It 'chains a pre-existing LocationChangedAction' {
        # The base handler and fnm use both run on every change.
        $global:BaseRan = 0
        $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction = { $global:BaseRan++ }

        Enable-FastNodeManager
        Set-Location $script:plainDir

        $global:BaseRan     | Should -Be 1
        $global:FnmUseCalls | Should -Be 1
    }

    It 'is reload-safe: re-running re-installs without stacking fnm calls' {
        Enable-FastNodeManager
        Enable-FastNodeManager      # simulates Import-Module -Force; . $PROFILE in a live session
        Set-Location $script:nodeDir
        $global:FnmUseCalls | Should -Be 1
    }

    It 'surfaces fnm output to the host (not swallowed inside the location hook)' {
        # PowerShell discards stdout emitted inside a LocationChangedAction, so the hook pipes fnm
        # through Out-Host. Shadow Out-Host to prove fnm's output is routed there; emit a line from
        # the fnm stub so there is something to surface. A regression to a bare `fnm use` (no pipe)
        # would leave the counter at 0.
        $global:OutHostHits = 0
        function global:Out-Host { $global:OutHostHits += @($input).Count }
        function global:fnm { if ($args -contains 'use') { 'Using Node v1.2.3' } else { '# fnm stub' } }

        Enable-FastNodeManager
        Set-Location $script:nodeDir

        $global:OutHostHits | Should -BeGreaterThan 0
    }
}
