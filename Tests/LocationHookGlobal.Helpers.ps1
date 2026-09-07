<#
    Shared BeforeEach/AfterEach helpers for the Enable-FastNodeManager / Enable-Zoxide location-hook
    tests. Not a *.Tests.ps1 file, so Pester's default discovery does not run it directly — each test
    file dot-sources it from its own BeforeAll.

    Both Enable-* functions stash bookkeeping in global variables (the hook can't close over module
    state and survive a reload). Since this module doubles as the author's own profile, the suite may
    run with a REAL hook already registered — its LocationChangedAction closure reads these globals,
    so AfterEach must restore them to their exact pre-test value (a real value if one was snapshotted,
    otherwise absent) rather than merely deleting them, or the restored real hook is left referencing
    variables that no longer exist and the next Set-Location anywhere later in the suite throws under
    StrictMode.
#>

function Backup-PwshProfileLocationHookGlobal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Name
    )

    $saved = @{}
    foreach ($n in $Name) {
        $existing = Get-Variable -Name $n -Scope Global -ErrorAction SilentlyContinue
        if ($existing) { $saved[$n] = $existing.Value }
    }
    Remove-Variable -Name $Name -Scope Global -ErrorAction SilentlyContinue
    $saved
}

function Restore-PwshProfileLocationHookGlobal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Name,

        [Parameter(Mandatory)]
        [hashtable]$Saved
    )

    foreach ($n in $Name) {
        if ($Saved.ContainsKey($n)) {
            Set-Variable -Name $n -Value $Saved[$n] -Scope Global
        }
        else {
            Remove-Variable -Name $n -Scope Global -ErrorAction SilentlyContinue
        }
    }
}
