function Enable-Ripgrep {
    <#
    .SYNOPSIS
        Installs (if necessary) and activates ripgrep, a very fast recursive content search.

    .DESCRIPTION
        Runs two nested Invoke-Step substeps:
          - Install: if rg.exe isn't on PATH, installs BurntSushi.ripgrep.MSVC with winget and patches
            the current session's PATH so the Initialize substep can see it immediately.
          - Initialize (guarded by Test-CommandAvailable): registers ripgrep's own PowerShell completer
            via `rg --generate complete-powershell` through Invoke-InGlobalScope.

        ripgrep searches file *contents* recursively, honoring .gitignore by default — the content-search
        counterpart to fd's filename search. Note the completion flag differs from fd's: ripgrep spells it
        `rg --generate complete-powershell`, not `--gen-completions powershell`.

        ripgrep is a standalone utility: it never aliases or replaces `grep`, `sls`, or Select-String.
        Enabling it only puts `rg` on PATH, with completion. If the install doesn't produce rg.exe on
        PATH, a warning is emitted and Initialize is skipped so startup continues.

    .EXAMPLE
        Enable-Ripgrep

        Installs ripgrep if needed and registers its tab completion.

    .NOTES
        Standalone content search (https://github.com/BurntSushi/ripgrep). Unlike bat and fd, ripgrep is
        not themed here: it exposes no color environment variable, and its only knob for default flags
        (colors, --smart-case, and the rest) is a config file pointed at by $env:RIPGREP_CONFIG_PATH.
        Writing that file is left to you rather than done at startup. It has no init-time dependency on
        the other tools, so its position in the startup order is free.
    #>
    [CmdletBinding()]
    param()

    Invoke-Step "Install" {
        # ripgrep is a winget portable: its exe lands in the default Links dir.
        Install-WingetPackageSafe -Id 'BurntSushi.ripgrep.MSVC' -Exe 'rg.exe' -CallerName 'Enable-Ripgrep'
    }

    Invoke-Step "Initialize" {
        if (Test-CommandAvailable -Name 'rg.exe') {
            # Global scope so ripgrep's completer isn't tagged to this module.
            Invoke-InGlobalScope ((rg --generate complete-powershell) | Out-String)
        }
    }
}
