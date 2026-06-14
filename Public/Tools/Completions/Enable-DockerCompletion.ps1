function Enable-DockerCompletion {
    <#
    .SYNOPSIS
        Registers tab completion for the Docker CLI (docker) in the current session.

    .DESCRIPTION
        Docker has no built-in PowerShell completion subcommand; its completion ships as the
        community `DockerCompletion` module on the PowerShell Gallery. This enabler imports that
        module via Import-ModuleSafe (which installs it CurrentUser-scoped on first use).

        Guarded by Get-Command: if `docker` isn't on PATH the function does nothing — so the
        DockerCompletion module is never fetched from the gallery on a machine without Docker, keeping
        with the "missing tool → skipped silently" contract of the other completion enablers. It only
        registers completion and opens no Invoke-Step of its own — the caller supplies the step label.

    .EXAMPLE
        Enable-DockerCompletion

        Imports DockerCompletion to enable docker tab completion, if docker is installed.

    .EXAMPLE
        Invoke-Step "Docker Completions" { Enable-DockerCompletion }

        Registers it as a rendered startup substep.
    #>
    [CmdletBinding()]
    param()

    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { return }

    Import-ModuleSafe DockerCompletion
}
