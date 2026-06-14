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
            version-file strategy) and registers fnm completions. When zoxide is also
            active, wraps zoxide's shared __zoxide_cd helper so every directory change
            triggers `fnm use`, switching node versions automatically.

        If the install doesn't produce fnm.exe on PATH, a warning is emitted (with winget's
        captured output) and Initialize is skipped (guarded by Get-Command) so profile startup
        continues.

    .EXAMPLE
        Enable-FastNodeManager

    .NOTES
        Call after Enable-Zoxide so the __zoxide_cd wrapping can take effect; without
        zoxide the env/completions setup still applies.
    #>
    [CmdletBinding()]
    param()

    Invoke-Step "Install" {
        # fnm is a winget portable: its exe lands in the Links dir.
        Install-WingetPackageSafe -Id 'Schniz.fnm' -Exe 'fnm.exe' `
            -PathDir (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links') `
            -CallerName 'Enable-FastNodeManager'
    }

    Invoke-Step "Initialize" {
        if (Get-Command fnm.exe -ErrorAction SilentlyContinue) {
            # Run in the global scope (not this module's) so the emitted env/completion helpers
            # aren't tagged to the module — see Private/Invoke-InGlobalScope.ps1.
            Invoke-InGlobalScope (fnm env --version-file-strategy=recursive --shell powershell | Out-String)
            Invoke-InGlobalScope (fnm completions --shell powershell | Out-String)

            if (Get-Command zoxide.exe -ErrorAction SilentlyContinue) {
                # Wrap the shared __zoxide_cd helper (used by both cd and cdi) so every
                # directory change triggers fnm. Run in the global scope so the redefined
                # function isn't tagged to the module; $function:__zoxide_cd then resolves to
                # zoxide's global helper, and $global:__zoxide_cd_base must be global so it's
                # in scope when the wrapper runs later from the prompt.
                Invoke-InGlobalScope @'
$global:__zoxide_cd_base = $function:__zoxide_cd
function global:__zoxide_cd($dir, $literal) {
    & $global:__zoxide_cd_base $dir $literal
    fnm use --silent-if-unchanged
}
'@
            }
        }
    }
}
