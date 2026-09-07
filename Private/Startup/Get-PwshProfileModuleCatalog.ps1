function Get-PwshProfileModuleCatalog {
    <#
    .SYNOPSIS
        Returns the PowerShell Gallery modules this profile installs on demand — the single source of
        truth for what lands in the user's module directory.

    .DESCRIPTION
        The winget CLIs are only half of what the profile puts on a machine; the other half is a set of
        gallery modules pulled in by Import-ModuleSafe, which installs any of them that is missing
        (Install-PSResource, CurrentUser scope, PSGallery) the first time it is needed. That happens
        quietly, in the middle of a startup step, so this catalog exists to let the installer say so up
        front rather than leaving it to be discovered.

        Each row carries:
          Name   — the gallery module id, exactly as Import-ModuleSafe is called with it.
          Label  — the name plus a short parenthetical, for display.
          Detail — $null when the module is always installed; otherwise the condition under which it
                   is fetched, shown INSTEAD of a flat "will install" so the list never promises an
                   install that may not happen (DockerCompletion on a machine with no docker, say).
          Url    — the project's homepage or repo, for the wizard's clickable inventory rows.

        Rows are in the order the profile reaches them: PwshSpectreConsole at module import, then the
        startup modules, then the three conditional ones.

        Unlike Get-PwshProfileToolCatalog this drives no install of its own — Import-ModuleSafe still
        installs each module where it is used, and this catalog only describes that. What keeps the two
        in step is Tests/ModuleCatalog.Tests.ps1, which walks the module's own source for every real
        Import-ModuleSafe call and asserts the two sets match exactly, in both directions.

    .EXAMPLE
        Get-PwshProfileModuleCatalog

        Returns every gallery module the profile may install, in the order it reaches them.

    .EXAMPLE
        @(Get-PwshProfileModuleCatalog | Where-Object { -not $_.Detail }).Name

        The modules installed unconditionally, as opposed to only under some condition.
    #>
    [CmdletBinding()]
    param()

    # Every row declares Detail even where it is $null: the suite runs under Set-StrictMode -Version
    # Latest, where reading a property a row omitted throws rather than returning $null.
    @(
        [pscustomobject]@{ Name = 'PwshSpectreConsole'; Label = 'PwshSpectreConsole (console UI)'
            Detail = $null; Url = 'https://github.com/ShaunLawrie/PwshSpectreConsole' }
        [pscustomobject]@{ Name = 'Terminal-Icons'; Label = 'Terminal-Icons (file icons)'
            Detail = $null; Url = 'https://github.com/devblackops/Terminal-Icons' }
        [pscustomobject]@{ Name = 'posh-git'; Label = 'posh-git (git in the prompt)'
            Detail = $null; Url = 'https://github.com/dahlbyk/posh-git' }
        [pscustomobject]@{ Name = 'PSFzf'; Label = 'PSFzf (fzf key bindings)'
            Detail = $null; Url = 'https://github.com/kelleyma49/PSFzf' }
        [pscustomobject]@{ Name = 'Microsoft.WinGet.Client'; Label = 'Microsoft.WinGet.Client (winget installs)'
            Detail = 'only when a winget install or setting needs it'
            Url = 'https://github.com/microsoft/winget-cli' }
        [pscustomobject]@{ Name = 'NerdFonts'; Label = 'NerdFonts (font downloads)'
            Detail = 'only if you opt into Nerd Fonts'; Url = 'https://github.com/PSModule/NerdFonts' }
        [pscustomobject]@{ Name = 'DockerCompletion'; Label = 'DockerCompletion (docker completion)'
            Detail = 'only when `docker` is on PATH'
            Url = 'https://github.com/matt9ucci/DockerCompletion' }
    )
}
