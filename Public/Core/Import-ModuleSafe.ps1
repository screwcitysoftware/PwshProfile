function Import-ModuleSafe {
    <#
    .SYNOPSIS
        Imports a module, installing it (CurrentUser scope) first if it isn't present.

    .DESCRIPTION
        Guards an Import-Module call so a missing module doesn't break profile startup:
          1. If the module isn't already available, install it with Install-PSResource
             into the CurrentUser scope.
          2. Import the module.
          3. If an initialization script block was supplied, run it after the import.

        Any failure to install or import is reported as a warning and swallowed so the rest
        of profile initialization continues; the initialization script is only run once the
        module has imported successfully.

    .PARAMETER Name
        Name of the module to ensure and import.

    .PARAMETER Initialize
        Optional script block run after the module is imported (e.g. setting module-specific
        environment variables or options).

    .PARAMETER Repair
        Optional recovery script block run when the import fails. After it runs the import is
        retried once, and a warning is only reported if that retry also fails. Use it to clean up
        state that wedges a module's import (e.g. Repair-TerminalIconsCache, which purges a
        corrupted Terminal-Icons theme cache so the re-import can regenerate it). With no -Repair
        an import failure is reported as a warning immediately, as before.

    .PARAMETER Scope
        Scope to install into when the module is missing. Defaults to 'CurrentUser'.

    .PARAMETER Repository
        Repository to install from when the module is missing. Defaults to 'PSGallery'.

    .EXAMPLE
        Import-ModuleSafe Terminal-Icons

    .EXAMPLE
        Import-ModuleSafe posh-git -Initialize { $env:POSH_GIT_ENABLED = $true }

    .EXAMPLE
        Import-ModuleSafe Terminal-Icons -Repair { Repair-TerminalIconsCache }

        Import Terminal-Icons; if it fails (e.g. a corrupted theme cache), run the repair and retry
        once before warning.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter(Position = 1)]
        [scriptblock]$Initialize,

        [Parameter()]
        [scriptblock]$Repair,

        [Parameter()]
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]$Scope = 'CurrentUser',

        [Parameter()]
        [string]$Repository = 'PSGallery'
    )

    if (-not (Get-Module -ListAvailable -Name $Name)) {
        try {
            Install-PSResource -Name $Name -Repository $Repository -Scope $Scope -TrustRepository -ErrorAction Stop
        }
        catch {
            Write-Warning "Import-ModuleSafe: could not install '$Name' from '$Repository': $($_.Exception.Message)"
            return
        }
    }

    try {
        Import-Module $Name -ErrorAction Stop
    }
    catch {
        if ($Repair) {
            # Best-effort recovery, then one retry; only warn if the retry also fails.
            & $Repair
            try {
                Import-Module $Name -ErrorAction Stop
            }
            catch {
                Write-Warning "Import-ModuleSafe: could not import '$Name': $($_.Exception.Message)"
                return
            }
        }
        else {
            Write-Warning "Import-ModuleSafe: could not import '$Name': $($_.Exception.Message)"
            return
        }
    }

    if ($Initialize) {
        & $Initialize
    }
}
