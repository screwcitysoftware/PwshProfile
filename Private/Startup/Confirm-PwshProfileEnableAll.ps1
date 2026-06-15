function Confirm-PwshProfileEnableAll {
    <#
    .SYNOPSIS
        Asks (interactively) whether to enable every catalog tool when Initialize-PwshProfile is
        called bare, returning the user's choice as a bool.

    .DESCRIPTION
        Backs the bare-call path of Initialize-PwshProfile: when neither -Enable nor -EnableAll is
        supplied there is no explicit selection, so rather than silently winget-installing every tool
        the orchestrator asks first. This helper centralizes that prompt and its guards.

        Failure-tolerance rules (this runs during profile startup, so it must never throw and never
        hang a non-interactive session):
          - Non-interactive host (no UserInteractive, or stdin redirected) -> return $false after one
            Write-Warning explaining how to choose tools. Never blocks waiting for input.
          - Interactive host -> a yes/no confirm defaulting to No, via Read-SpectreConfirm when
            PwshSpectreConsole is available, else a plain Read-Host fallback.
          - Any unexpected error -> caught, warned once, and treated as No.

        Wizard-generated profiles always pass -Enable or -EnableAll, so this prompt is only ever hit
        by a hand-typed bare `Initialize-PwshProfile`; the warning steers such users toward making an
        explicit, permanent choice.

    .PARAMETER Catalog
        The full list of opt-in tool tokens (from Get-PwshProfileToolCatalog -Token), used only to
        report the count in the prompt/warning.

    .EXAMPLE
        if (Confirm-PwshProfileEnableAll -Catalog (Get-PwshProfileToolCatalog -Token)) { ... }

        Prompts the user (interactively) and returns $true to enable all tools, $false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Position = 0)]
        [string[]]$Catalog = @()
    )

    $count = @($Catalog).Count

    try {
        # Don't prompt (and never block) when there's no interactive user or stdin is redirected.
        $interactive = [Environment]::UserInteractive -and -not [Console]::IsInputRedirected
        if (-not $interactive) {
            Write-Warning "Initialize-PwshProfile was called with no tool selection in a non-interactive session; enabling nothing. Pass -Enable <tools> or -EnableAll, or run Install-PwshProfile to choose."
            return $false
        }

        $message = "Initialize-PwshProfile has no tool selection. Enable all $count tools now (missing ones are winget-installed)? Pass -Enable/-EnableAll or run Install-PwshProfile to make a permanent choice."

        if (Get-Command Read-SpectreConfirm -ErrorAction SilentlyContinue) {
            return [bool](Read-SpectreConfirm -Message $message -DefaultAnswer 'n')
        }

        # Plain fallback when PwshSpectreConsole isn't available — still interactive, so safe to ask.
        $answer = Read-Host "$message [y/N]"
        return ($answer -match '^\s*y(es)?\s*$')
    }
    catch {
        Write-Warning "Confirm-PwshProfileEnableAll: could not prompt ($($_.Exception.Message)); enabling nothing. Pass -Enable/-EnableAll or run Install-PwshProfile."
        return $false
    }
}
