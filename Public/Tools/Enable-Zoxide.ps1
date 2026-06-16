function Enable-Zoxide {
    <#
    .SYNOPSIS
        Installs (if necessary) and activates zoxide directory jumping for the session.

    .DESCRIPTION
        Runs two nested Invoke-Step substeps:
          - Install: if zoxide.exe isn't on PATH, installs it with winget
            (ajeetdsouza.zoxide, a portable package) and patches the current session's PATH
            so the Initialize substep can see it immediately.
          - Initialize: runs `zoxide init powershell --hook none` and invokes the emitted script,
            which defines the global __zoxide_* jump helpers and the cd/cdi aliases (but NOT a
            prompt wrapper), then registers a LocationChangedAction hook that records each
            directory you change into (via `zoxide add`).

        The `--hook none` + LocationChangedAction design replaces zoxide's default prompt-wrapping
        hook because that wrap is fragile: oh-my-posh defines `prompt` inside a global dynamic
        module it removes and re-adds on every init, and zoxide guards its wrap with a one-shot
        flag — so a profile reload (or anything that redefines `prompt` after startup) silently
        drops zoxide's prompt hook and directories stop being tracked. PowerShell's
        $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction (6.2+) fires after *any*
        location change (cd, z/cdi, Set-Location, Push-Location, .., …) and is immune to prompt
        re-definition. The hook chains any pre-existing LocationChangedAction and is guarded against
        re-registering on reload — the same mechanism Enable-FastNodeManager uses, so the two
        compose (both fire on every change).

        If the install doesn't produce zoxide.exe on PATH, a warning is emitted (with winget's
        captured output) and Initialize is skipped (guarded by Get-Command) so profile startup
        continues.

    .PARAMETER Command
        The command name zoxide binds for jumping, passed as `--cmd`. Defaults to 'cd',
        which replaces the built-in cd (and adds cdi for interactive selection).

    .EXAMPLE
        Enable-Zoxide

    .EXAMPLE
        Enable-Zoxide -Command z

    .NOTES
        Independent of oh-my-posh and of call order: directory tracking is a LocationChangedAction,
        not a wrap of the prompt, so it survives a profile reload and any later prompt redefinition.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Command = 'cd'
    )

    Invoke-Step "Install" {
        # zoxide is a winget portable: its exe lands in the default Links dir.
        Install-WingetPackageSafe -Id 'ajeetdsouza.zoxide' -Exe 'zoxide.exe' -CallerName 'Enable-Zoxide'
    }

    Invoke-Step "Initialize" {
        if (Get-Command zoxide.exe -ErrorAction SilentlyContinue) {
            # Run in the global scope (not this module's) so the emitted __zoxide_* helpers and
            # cd/cdi aliases aren't tagged to the module — see Private/Invoke-InGlobalScope.ps1.
            # `--hook none` skips zoxide's default prompt wrapper (we track directories via
            # LocationChangedAction below instead — the prompt wrap is wiped by oh-my-posh's
            # remove/re-add of its prompt module on reload, so directories silently stop tracking).
            Invoke-InGlobalScope (zoxide init powershell --cmd $Command --hook none | Out-String)

            # Record each directory you change into via PowerShell's LocationChangedAction (fires for
            # cd, z/cdi, Set-Location, Push-Location, .., etc.), which is immune to prompt redefinition
            # — unlike zoxide's prompt hook. Run in the global scope so the handler and its
            # $global:__zoxide_loc_base capture aren't tagged to the module and resolve when the hook
            # fires later from the prompt.
            #
            # Capture any pre-existing handler ONCE (guarded by $global:__zoxide_loc_hooked) so a
            # profile reload doesn't re-capture our own wrapper and stack zoxide add calls. But always
            # (re)install the wrapper, so reloading the profile in a live session repairs the hook
            # rather than leaving a stale one frozen behind the guard. This composes with
            # Enable-FastNodeManager's LocationChangedAction (each captures the other as its base and
            # both fire); Enable-Zoxide runs before Enable-FastNodeManager, so zoxide's base is the
            # pre-existing handler (usually $null) and fnm chains onto zoxide's wrapper.
            Invoke-InGlobalScope @'
if (-not (Get-Variable -Name __zoxide_loc_hooked -Scope Global -ErrorAction SilentlyContinue)) {
    $global:__zoxide_loc_base = $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction
    $global:__zoxide_loc_hooked = $true
}
$ExecutionContext.SessionState.InvokeCommand.LocationChangedAction = {
    param($source, $eventArgs)
    # The captured base is an EventHandler delegate (the property's type), so call .Invoke.
    if ($null -ne $global:__zoxide_loc_base) { $global:__zoxide_loc_base.Invoke($source, $eventArgs) }
    # Only record real filesystem directories: guard on the FileSystem provider so cd into
    # Registry:/Cert: is a no-op. The event fires only on actual location changes, so zoxide add's
    # natural dedup (by path) is all we need. zoxide add prints nothing, so no Out-Host is required.
    $new = $eventArgs.NewPath
    if ($new -and $new.Provider.Name -eq 'FileSystem') {
        zoxide add "--" $new.ProviderPath
    }
}
'@
        }
    }
}
