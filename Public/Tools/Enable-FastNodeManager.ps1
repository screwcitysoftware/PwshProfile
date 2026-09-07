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
        Spawning fnm costs roughly 41ms, and paying that on every `cd` is latency you feel, so the
        hook first walks up for the files fnm itself reads — `.nvmrc`, `.node-version`, `package.json` —
        at about 2ms, stamping each with its write time, and runs `fnm use --silent-if-unchanged`
        only when that stamp changes. Unchanged means fnm would resolve identically.

        Three details make the gate correct. It compares the stamp rather than merely checking
        whether a version file exists, because fnm reverts to the default on the way OUT of a
        project — skipping there would strand the project's version after you cd away. It includes
        the write time, so bumping a pinned version is picked up on the next cd rather than only
        after leaving and re-entering. And it stamps every version file up the chain, since a nearer
        `package.json` without an `engines.node` field does not stop fnm resolving a `.nvmrc`
        further up. Moving inside one project without editing, or between two non-Node directories,
        is skipped.

        It chains any pre-existing LocationChangedAction and is guarded against re-registering on
        profile reload.

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

            # Auto-switch the node version on directory change via LocationChangedAction (fires for
            # cd, z/cdi, Set-Location, Push-Location, .., etc.), so it works without zoxide and
            # regardless of zoxide's --cmd. Global scope so the handler and its globals resolve when
            # the hook fires later from the prompt.
            # Capture the pre-existing handler once ($global:__fnm_loc_hooked) so a reload doesn't
            # re-capture our own wrapper and stack fnm calls, but always reinstall the wrapper so a
            # reload repairs it. The base is Enable-Zoxide's handler (it runs first) or $null.
            Invoke-InGlobalScope @'
if (-not (Get-Variable -Name __fnm_loc_hooked -Scope Global -ErrorAction SilentlyContinue)) {
    $global:__fnm_loc_base = $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction
    $global:__fnm_loc_hooked = $true
}
if (-not (Get-Variable -Name __fnm_last_version_stamp -Scope Global -ErrorAction SilentlyContinue)) {
    $global:__fnm_last_version_stamp = $null
}
$ExecutionContext.SessionState.InvokeCommand.LocationChangedAction = {
    param($source, $eventArgs)
    # The captured base is an EventHandler delegate (the property's type), so call .Invoke.
    if ($null -ne $global:__fnm_loc_base) { $global:__fnm_loc_base.Invoke($source, $eventArgs) }

    # Guard on the FileSystem provider so cd into Registry:/Cert: is a no-op.
    $new = $eventArgs.NewPath
    if (-not $new -or $new.Provider.Name -ne 'FileSystem') { return }

    # Stamp what fnm would see, walking up as its recursive strategy does. Spawning fnm costs ~41ms on
    # EVERY directory change; this walk costs ~2ms. The file list must cover at least what fnm reads --
    # verified as .nvmrc, .node-version and package.json (engines.node). Erring wide only costs a
    # redundant spawn; erring narrow leaves the wrong node version active.
    #
    # Every version file up the chain is stamped, not just the nearest: a closer package.json without
    # an engines.node field does not stop fnm resolving a .nvmrc further up, so tracking only the first
    # match would miss an edit to the file actually in effect. The write time is part of the stamp so
    # bumping a pinned version is picked up on the next cd, rather than only after leaving and
    # re-entering the project.
    $parts = [System.Collections.Generic.List[string]]::new()
    $dir = $new.ProviderPath
    while ($dir) {
        foreach ($name in '.nvmrc', '.node-version', 'package.json') {
            $candidate = Join-Path $dir $name
            if ([System.IO.File]::Exists($candidate)) {
                $parts.Add($candidate + '|' + [System.IO.File]::GetLastWriteTimeUtc($candidate).Ticks)
            }
        }
        $parent = Split-Path $dir -Parent
        if (-not $parent -or $parent -eq $dir) { break }
        $dir = $parent
    }
    $stamp = $parts -join "`n"

    # Only call fnm when that stamp changes. Unchanged means fnm would resolve identically, so the
    # spawn is pure cost. Crucially an empty stamp still differs from a non-empty one, so this fires on
    # the way OUT of a project -- the transition that reverts to the default version. A naive "skip
    # when no version file" would leave the project's version active after you cd away.
    if ($stamp -ne $global:__fnm_last_version_stamp) {
        $global:__fnm_last_version_stamp = $stamp
        fnm use --silent-if-unchanged | Out-Host
    }
}
'@
        }
    }
}
