function Enable-Fzf {
    <#
    .SYNOPSIS
        Installs (if necessary) fzf, the command-line fuzzy finder, for the session.

    .DESCRIPTION
        Runs two nested Invoke-Step substeps:
          - Install: if fzf.exe isn't on PATH, installs it with winget (junegunn.fzf, a
            portable package) and patches the current session's PATH so the exe is usable
            immediately.
          - Initialize: a Get-Command-guarded no-op. fzf needs no PowerShell shell-init script
            (unlike zoxide's `zoxide init powershell`), so there's nothing to run — the substep
            exists only to keep the install/initialize shape consistent with the other tool
            enablers and to gate on the exe being present.

        If the install doesn't produce fzf.exe on PATH, a warning is emitted (with winget's
        captured output) so profile startup continues either way.

        fzf and zoxide are independent, standalone tools, but zoxide is built to integrate with
        fzf: when fzf.exe is on PATH, zoxide's interactive directory picker (`cdi` / `zi`)
        automatically uses fzf for fuzzy selection. Enabling fzf alongside zoxide therefore gives
        zoxide's interactive jump its fuzzy-finder UI for free.

    .EXAMPLE
        Enable-Fzf

    .NOTES
        Standalone fuzzy finder (https://github.com/junegunn/fzf). zoxide auto-detects fzf on PATH
        for its `cdi`/`zi` interactive picker, so pairing the two is the common reason to enable
        fzf here — but neither tool requires the other to function.
    #>
    [CmdletBinding()]
    param()

    Invoke-Step "Install" {
        # fzf is a winget portable: its exe lands in the Links dir.
        Install-WingetPackageSafe -Id 'junegunn.fzf' -Exe 'fzf.exe' `
            -PathDir (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links') `
            -CallerName 'Enable-Fzf'
    }

    Invoke-Step "Initialize" {
        if (Get-Command fzf.exe -ErrorAction SilentlyContinue) {
            # No-op: fzf has no PowerShell init/completion script to run. Just having fzf.exe on
            # PATH is enough — zoxide auto-detects it for its `cdi`/`zi` interactive picker.
        }
    }
}
