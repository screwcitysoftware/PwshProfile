function Get-BundledThemeCompletion {
    <#
    .SYNOPSIS
        Returns tab-completion results for a bundled theme name, filtered by the word typed so far.

    .DESCRIPTION
        The shared body behind every `-Theme`/`-Name` ArgumentCompleter that accepts a bundled theme:
        Initialize-PwshProfile, Get-OhMyPoshTheme, Export-OhMyPoshTheme, Install-WindowsTerminalScheme,
        Uninstall-WindowsTerminalScheme, and Show-PwshProfileReadme. An ArgumentCompleter scriptblock
        executes in the caller's scope, where this private function isn't visible — each call site
        still reaches it through `& (Get-Module ScrewCitySoftware.PwshProfile | Select-Object -Last 1) { ... }`,
        but the filtering and CompletionResult construction now live in one place instead of six. The
        `Select-Object -Last 1` matters: `Get-Module` returns an array when more than one copy of the
        module is loaded at once (e.g. a dev checkout alongside a staged build, both named
        ScrewCitySoftware.PwshProfile) — `&` can't invoke an array, the completer throws (silently,
        since ArgumentCompleter swallows exceptions), and PowerShell falls back to default file-path
        completion, which looks like "the completer isn't working" rather than an error.

    .PARAMETER WordToComplete
        The partial theme name typed so far.

    .EXAMPLE
        Get-BundledThemeCompletion -WordToComplete 'scr'

        Returns a CompletionResult for 'screwcity'.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.CompletionResult])]
    param(
        [Parameter(Position = 0)]
        [string]$WordToComplete
    )

    Get-BundledThemeName | Where-Object { $_ -like "$WordToComplete*" } |
        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}
