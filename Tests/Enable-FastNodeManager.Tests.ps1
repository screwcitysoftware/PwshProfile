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
        Mock -ModuleName $script:Module Test-CommandAvailable { $true } -ParameterFilter { $Name -eq 'fnm.exe' }

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
        # Snapshot (not just clear) any pre-existing hook globals. If a real profile's
        # Enable-FastNodeManager was already active before the suite ran (this module doubles as the
        # author's own profile), $script:savedLoc above just captured a REAL hook closure that itself
        # reads these globals -- AfterEach must put them back exactly, not merely delete them, or
        # restoring that real hook leaves it referencing variables that no longer exist, so the very
        # next Set-Location anywhere later in the suite throws under StrictMode.
        $script:savedFnmGlobals = @{}
        foreach ($name in '__fnm_loc_hooked', '__fnm_loc_base', '__fnm_last_version_stamp') {
            $existing = Get-Variable -Name $name -Scope Global -ErrorAction SilentlyContinue
            if ($existing) { $script:savedFnmGlobals[$name] = $existing.Value }
        }
        Remove-Variable -Name __fnm_loc_hooked, __fnm_loc_base, __fnm_last_version_stamp -Scope Global -ErrorAction SilentlyContinue

        # An isolated temp tree with two real directories to move between: one IS a Node project
        # (carries a .node-version file), one is not. The hook only spawns fnm when the resolved
        # version file changes, so both are needed to exercise entering, leaving, and staying out.
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
        # Remove the global function shims the tests defined. The Function: provider ignores a
        # 'global:' qualifier in the path, so use the bare name. Done here rather than inline so a
        # shim can't leak into a later test file if a test throws — a leaked Out-Host reading the
        # cleared $global:OutHostHits breaks every later test under StrictMode (how CI runs).
        Remove-Item Function:fnm, Function:Out-Host -ErrorAction SilentlyContinue
        Remove-Variable -Name FnmUseCalls, OutHostHits, BaseRan -Scope Global -ErrorAction SilentlyContinue
        # Restore the hook globals to their pre-test state (a real value if one was snapshotted above,
        # otherwise absent) rather than unconditionally deleting them -- see the BeforeEach comment.
        foreach ($name in '__fnm_loc_hooked', '__fnm_loc_base', '__fnm_last_version_stamp') {
            if ($script:savedFnmGlobals.ContainsKey($name)) {
                Set-Variable -Name $name -Value $script:savedFnmGlobals[$name] -Scope Global
            }
            else {
                Remove-Variable -Name $name -Scope Global -ErrorAction SilentlyContinue
            }
        }
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

    It 'runs fnm use when LEAVING a Node project, so fnm reverts to the default version' {
        # The critical case for the version-file gate. fnm switches back to the default on its way out
        # of a project (verified against fnm 1.x), so skipping the spawn merely because the new
        # directory has no version file would strand the project's version after you cd away.
        Enable-FastNodeManager
        Set-Location $script:nodeDir
        $global:FnmUseCalls = 0
        Set-Location $script:plainDir
        $global:FnmUseCalls | Should -Be 1
    }

    It 'skips fnm when neither directory resolves to a version file' {
        # Spawning fnm costs ~41ms on every directory change; outside a Node tree it can only ever
        # resolve to the same default, so the spawn is pure latency.
        Enable-FastNodeManager
        Set-Location $script:plainDir
        $global:FnmUseCalls = 0
        Set-Location $script:testRoot
        $global:FnmUseCalls | Should -Be 0
    }

    It 'skips fnm when moving deeper inside the same Node project' {
        Enable-FastNodeManager
        Set-Location $script:nodeDir
        $global:FnmUseCalls = 0
        $deep = Join-Path $script:nodeDir 'src'
        New-Item -ItemType Directory -Path $deep -Force | Out-Null
        Set-Location $deep
        $global:FnmUseCalls | Should -Be 0
    }

    It 'runs fnm again when a version file is edited, even without leaving the project' {
        # The stamp carries each version file's write time, not just its path. Without that, bumping
        # .node-version and cd-ing to a subdirectory would silently keep the old node version until
        # you left the project and came back.
        Enable-FastNodeManager
        Set-Location $script:nodeDir
        $global:FnmUseCalls = 0

        $versionFile = Join-Path $script:nodeDir '.node-version'
        Set-Content -LiteralPath $versionFile -Value 'v22.0.0'
        # Stamp an explicit time rather than relying on filesystem clock granularity.
        [System.IO.File]::SetLastWriteTimeUtc($versionFile, (Get-Date).ToUniversalTime().AddMinutes(1))

        $deep = Join-Path $script:nodeDir 'src'
        New-Item -ItemType Directory -Path $deep -Force | Out-Null
        Set-Location $deep
        $global:FnmUseCalls | Should -Be 1
    }

    It 'chains a pre-existing LocationChangedAction' {
        # The base handler and fnm use both run on every change.
        $global:BaseRan = 0
        $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction = { $global:BaseRan++ }

        Enable-FastNodeManager
        Set-Location $script:nodeDir

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
        # through Out-Host. Shadow Out-Host to prove the output is routed there; a regression to a
        # bare `fnm use` would leave the counter at 0.
        $global:OutHostHits = 0
        function global:Out-Host { $global:OutHostHits += @($input).Count }
        function global:fnm { if ($args -contains 'use') { 'Using Node v1.2.3' } else { '# fnm stub' } }

        Enable-FastNodeManager
        Set-Location $script:nodeDir

        $global:OutHostHits | Should -BeGreaterThan 0
    }
}
