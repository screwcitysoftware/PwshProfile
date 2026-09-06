function Enable-Xh {
    <#
    .SYNOPSIS
        Installs (if necessary) and activates the xh HTTP client for the session.

    .DESCRIPTION
        Runs two nested Invoke-Step substeps:
          - Install: if xh.exe isn't on PATH, installs it with winget (ducaale.xh, a
            portable package that also ships xhs.exe) and patches the current session's
            PATH so the Initialize substep can see it immediately.
          - Initialize: registers tab completion for xh and xhs, and under -ReplaceHttp also
            aliases http -> xh.exe and https -> xhs.exe globally (extending the generated
            completers to cover those aliases).

        If the install doesn't produce xh.exe on PATH, a warning is emitted (with winget's
        captured output) and Initialize is skipped (guarded by Get-Command) so profile startup
        continues.

    .PARAMETER ReplaceHttp
        Alias http -> xh.exe and https -> xhs.exe for the session, and widen each generated
        completer to cover its alias. Off by default: unlike cat and more, `http`/`https` are not
        built-in PowerShell commands, so this claims two previously-free names in the global
        command namespace rather than shadowing anything. The completer widening rides this switch
        because a completion registered for `http` is meaningless when `http` isn't a command.

    .EXAMPLE
        Enable-Xh

        Installs xh if needed and registers completion for `xh` and `xhs` only.

    .EXAMPLE
        Enable-Xh -ReplaceHttp

        Also binds `http` and `https` to xh/xhs, with completion following the aliases.

    .NOTES
        Fast, friendly HTTP client (https://github.com/ducaale/xh). Since PowerShell completers do not
        follow aliases, the alias completion is done by widening xh's own `-CommandName 'xh'` literal;
        that -replace is coupled to xh's exact output, so a format change there silently drops the
        alias's completion (the tool's own completion keeps working).
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$ReplaceHttp
    )

    Invoke-Step "Install" {
        # xh is a winget portable (also ships xhs.exe): its exes land in the default Links dir.
        Install-WingetPackageSafe -Id 'ducaale.xh' -Exe 'xh.exe' -CallerName 'Enable-Xh'
    }

    Invoke-Step "Initialize" {
        if (Test-CommandAvailable -Name 'xh.exe') {
            # Global scope so the registered completer isn't tagged to this module. Under -ReplaceHttp
            # the -replace extends xh's completer to cover the `http` alias; it is coupled to xh's exact
            # `-CommandName 'xh'` output, so a format change there silently drops `http` completion.
            $xhCompleter = (xh --generate complete-powershell) | Out-String
            if ($ReplaceHttp) {
                Set-Alias -Name http -Value xh.exe -Scope Global
                $xhCompleter = $xhCompleter -replace "-CommandName 'xh'", "-CommandName 'xh', 'http'"
            }
            Invoke-InGlobalScope $xhCompleter
        }

        if (Test-CommandAvailable -Name 'xhs.exe') {
            # Same coupling: a change to xhs's `-CommandName 'xhs'` output silently drops `https`.
            $xhsCompleter = (xhs --generate complete-powershell) | Out-String
            if ($ReplaceHttp) {
                Set-Alias -Name https -Value xhs.exe -Scope Global
                $xhsCompleter = $xhsCompleter -replace "-CommandName 'xhs'", "-CommandName 'xhs', 'https'"
            }
            Invoke-InGlobalScope $xhsCompleter
        }
    }
}
