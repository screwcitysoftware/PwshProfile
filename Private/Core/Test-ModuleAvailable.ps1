function Test-ModuleAvailable {
    <#
    .SYNOPSIS
        Reports whether a module is already loaded or installed, without enumerating every module on
        PSModulePath.

    .DESCRIPTION
        The cheap existence check behind Import-ModuleSafe's "install it if it's missing" branch.

        The obvious form, Get-Module -ListAvailable -Name <name>, walks PSModulePath and parses every
        manifest it finds: measured at ~50ms per call whether or not the module exists. Import-ModuleSafe
        runs about five times per shell start (PwshSpectreConsole, Terminal-Icons, posh-git, PSFzf,
        DockerCompletion), so that is ~250ms of startup spent answering a yes/no question.

        This answers the same question two cheaper ways: a loaded-module check (free, and the only thing
        that catches a module imported by full path, whose folder is not on PSModulePath), then a
        directory probe of PSModulePath (~0.3ms).

        It is deliberately a heuristic, not a manifest validation. A false positive — a folder with a
        broken or absent manifest — simply means the caller's Import-Module fails and takes its existing
        warning path, so the module's failure tolerance is unchanged. What it must never do is report
        $false for a module that IS installed, which would trigger a needless gallery install; the
        directory probe is the same lookup PowerShell itself uses to find a module by name.

    .PARAMETER Name
        The module name to look for.

    .EXAMPLE
        if (-not (Test-ModuleAvailable -Name 'posh-git')) { Install-PSResource -Name 'posh-git' }

        The Import-ModuleSafe pattern: install only when the module isn't already there.

    .NOTES
        Kept separate from Import-ModuleSafe so the probe can be tested on its own, and so a future
        change to how modules are discovered has one place to land.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    if (Get-Module -Name $Name) { return $true }

    foreach ($dir in ($env:PSModulePath -split [System.IO.Path]::PathSeparator)) {
        if ($dir -and [System.IO.Directory]::Exists((Join-Path $dir $Name))) { return $true }
    }
    $false
}
