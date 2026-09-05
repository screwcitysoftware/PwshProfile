function Enable-Xh {
    <#
    .SYNOPSIS
        Installs (if necessary) and activates the xh HTTP client for the session.

    .DESCRIPTION
        Runs two nested Invoke-Step substeps:
          - Install: if xh.exe isn't on PATH, installs it with winget (ducaale.xh, a
            portable package that also ships xhs.exe) and patches the current session's
            PATH so the Initialize substep can see it immediately.
          - Initialize: aliases http -> xh.exe and https -> xhs.exe globally, and registers
            tab completion for all four command names (the generated completer is extended
            to cover the aliases).

        If the install doesn't produce xh.exe on PATH, a warning is emitted (with winget's
        captured output) and Initialize is skipped (guarded by Get-Command) so profile startup
        continues.

    .EXAMPLE
        Enable-Xh
    #>
    [CmdletBinding()]
    param()

    Invoke-Step "Install" {
        # xh is a winget portable (also ships xhs.exe): its exes land in the default Links dir.
        Install-WingetPackageSafe -Id 'ducaale.xh' -Exe 'xh.exe' -CallerName 'Enable-Xh'
    }

    Invoke-Step "Initialize" {
        if (Get-Command xh.exe -ErrorAction SilentlyContinue) {
            Set-Alias -Name http -Value xh.exe -Scope Global
            # Global scope so the registered completer isn't tagged to this module. The -replace extends
            # xh's completer to cover the `http` alias; it is coupled to xh's exact `-CommandName 'xh'`
            # output, so a format change there silently drops `http` completion.
            Invoke-InGlobalScope ((xh --generate complete-powershell) -replace "-CommandName 'xh'", "-CommandName 'xh', 'http'" | Out-String)
        }

        if (Get-Command xhs.exe -ErrorAction SilentlyContinue) {
            Set-Alias -Name https -Value xhs.exe -Scope Global
            # Same coupling: a change to xhs's `-CommandName 'xhs'` output silently drops `https`.
            Invoke-InGlobalScope ((xhs --generate complete-powershell) -replace "-CommandName 'xhs'", "-CommandName 'xhs', 'https'" | Out-String)
        }
    }
}
