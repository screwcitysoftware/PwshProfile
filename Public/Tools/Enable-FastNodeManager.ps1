function Enable-FastNodeManager {
    <#
    .SYNOPSIS
        Installs (if necessary) and activates Fast Node Manager (fnm) for the session.

    .DESCRIPTION
        Runs two nested Invoke-Step substeps:
          - Install: if fnm.exe isn't on PATH, installs it with winget (Schniz.fnm, a
            portable package) and patches the current session's PATH so the Initialize
            substep can see it immediately.
          - Initialize: applies `fnm env` (multishell PATH + FNM_* variables, recursive
            version-file strategy) and registers fnm completions, then registers a
            LocationChangedAction hook so changing into a Node project auto-switches the node
            version (via `fnm use`).

        The directory hook uses PowerShell's
        $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction (6.2+), which fires
        after *any* location change — `cd`, `z`/`cdi`, `Set-Location`, `Push-Location`, `..` —
        so it works whether or not zoxide is enabled and regardless of zoxide's jump command.
        On every filesystem change it runs `fnm use --silent-if-unchanged`: fnm resolves the
        version recursively (the strategy set by `fnm env`), reverting to the default version
        outside a Node project, and emits nothing unless the active version actually changes — so
        moving around a non-Node tree is silent and produces no error. It chains any pre-existing
        LocationChangedAction and is guarded against re-registering on profile reload.

        If the install doesn't produce fnm.exe on PATH, a warning is emitted (with winget's
        captured output) and Initialize is skipped (guarded by Get-Command) so profile startup
        continues.

    .EXAMPLE
        Enable-FastNodeManager

    .NOTES
        Independent of zoxide and of call order: the directory hook is a LocationChangedAction,
        not a wrap of zoxide's cd helper, so no "call after Enable-Zoxide" requirement applies.
    #>
    [CmdletBinding()]
    param()

    Invoke-Step "Install" {
        # fnm is a winget portable: its exe lands in the default Links dir.
        Install-WingetPackageSafe -Id 'Schniz.fnm' -Exe 'fnm.exe' -CallerName 'Enable-FastNodeManager'
    }

    Invoke-Step "Initialize" {
        if (Test-CommandAvailable -Name 'fnm.exe') {
            # Global scope so the emitted env/completion helpers aren't tagged to this module.
            Invoke-InGlobalScope (fnm env --version-file-strategy=recursive --shell powershell | Out-String)
            Invoke-InGlobalScope (fnm completions --shell powershell | Out-String)

            # Auto-switch the node version on every directory change via LocationChangedAction (fires
            # for cd, z/cdi, Set-Location, Push-Location, .., etc.), so it works without zoxide and
            # regardless of zoxide's --cmd. Global scope so the handler and its $global:__fnm_loc_base
            # capture resolve when the hook fires later from the prompt.
            # Capture the pre-existing handler once ($global:__fnm_loc_hooked) so a reload doesn't
            # re-capture our own wrapper and stack fnm calls, but always reinstall the wrapper so a
            # reload repairs it. The base is Enable-Zoxide's handler (it runs first) or $null.
            Invoke-InGlobalScope @'
if (-not (Get-Variable -Name __fnm_loc_hooked -Scope Global -ErrorAction SilentlyContinue)) {
    $global:__fnm_loc_base = $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction
    $global:__fnm_loc_hooked = $true
}
$ExecutionContext.SessionState.InvokeCommand.LocationChangedAction = {
    param($source, $eventArgs)
    # The captured base is an EventHandler delegate (the property's type), so call .Invoke.
    if ($null -ne $global:__fnm_loc_base) { $global:__fnm_loc_base.Invoke($source, $eventArgs) }
    # fnm resolves the version recursively (FNM_VERSION_FILE_STRATEGY from `fnm env`) and with
    # --silent-if-unchanged emits nothing unless the active version changes, so no version-file gate is
    # needed. Guard on the FileSystem provider so cd into Registry:/Cert: is a no-op. Out-Host is
    # required: PowerShell discards stdout emitted inside a LocationChangedAction.
    $new = $eventArgs.NewPath
    if ($new -and $new.Provider.Name -eq 'FileSystem') {
        fnm use --silent-if-unchanged | Out-Host
    }
}
'@
        }
    }
}
