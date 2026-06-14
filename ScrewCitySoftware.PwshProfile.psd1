@{
    RootModule        = 'ScrewCitySoftware.PwshProfile.psm1'
    ModuleVersion     = '0.5.0'
    GUID              = '4382ebfd-1c06-4409-b7ee-89c3c386b6b0'
    Author            = 'Jason Rotello'
    CompanyName       = 'Screw City Software'   # "Screw City" = Rockford, Illinois (screw/fastener heritage)
    Copyright         = '(c) 2026 Jason Rotello / Screw City Software. Licensed under the MIT License.'
    Description       = 'Reusable building blocks for PowerShell profile startup: timed startup steps, safe module imports, PSReadLine setup, and CLI tool enablers (oh-my-posh, zoxide, fnm, xh).'
    PowerShellVersion = '7.4'

    # Explicit export list (no wildcards) so module discovery doesn't have to load the
    # module. Must be kept in sync with the files in Public/.
    FunctionsToExport = @(
        'Install-PwshProfile'
        'Uninstall-PwshProfile'
        'Show-NerdFontSetup'
        'Initialize-PwshProfile'
        'Invoke-Step'
        'Import-ModuleSafe'
        'Initialize-PSReadline'
        'Write-Figlet'
        'Show-FigletFont'
        'Enable-OhMyPosh'
        'Get-OhMyPoshTheme'
        'Export-OhMyPoshTheme'
        'Enable-Zoxide'
        'Enable-Fzf'
        'Enable-FastNodeManager'
        'Enable-Xh'
        'Enable-WingetCompletion'
        'Enable-AzCompletion'
        'Enable-TailscaleCompletion'
        'Enable-DockerCompletion'
        'Enable-1PasswordCompletion'
        'Enable-GithubCliCompletion'
        'Set-WingetSetting'
        'Show-PwshProfileReadme'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('profile', 'startup', 'PSReadLine', 'oh-my-posh', 'zoxide', 'fnm', 'xh')
            LicenseUri   = 'https://opensource.org/licenses/MIT'
            ProjectUri   = 'https://github.com/screwcitysoftware/PwshProfile'
            IconUri      = 'https://raw.githubusercontent.com/screwcitysoftware/PwshProfile/main/Assets/icon.png'
            ReleaseNotes = 'https://github.com/screwcitysoftware/PwshProfile/releases'
        }
    }
}
