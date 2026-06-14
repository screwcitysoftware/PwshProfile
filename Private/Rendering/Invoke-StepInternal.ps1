function Invoke-StepInternal {
    <#
    .SYNOPSIS
        Per-step worker for Invoke-Step's Spectre status renderer.

    .DESCRIPTION
        Pushes the step's description onto the $script:StepPath breadcrumb and updates the
        spinner whose context Invoke-Step stashed in $script:StepStatusContext (this function
        assumes it is set) to show the full path, e.g. "🔩 Tools › fnm › Install". When the body
        finishes the segment is popped and the parent's breadcrumb is restored; the top-level
        segment owns the icon ($script:StepRootIcon) — nested custom icons aren't shown.

        Body pipeline output is discarded and body exceptions propagate, matching the classic
        renderer; the breadcrumb pop/restore happens in a finally block so a failing step can't
        corrupt the spinner text for later steps.

    .EXAMPLE
        Invoke-StepInternal -Description 'Install' -ScriptBlock { winget install ... } -Icon ':nut_and_bolt:'
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Description,
        [Parameter(Mandatory)]
        [ScriptBlock]$ScriptBlock,
        [Parameter()]
        [string]$Icon
    )

    if ($script:StepPath.Count -eq 0) {
        $script:StepRootIcon = $Icon   # root segment owns the breadcrumb's icon
    }
    $script:StepPath.Add($Description)
    $script:StepStatusContext.Status = Format-StepStatus

    try {
        $null = & $ScriptBlock   # body pipeline output discarded, as always; exceptions propagate
    }
    finally {
        $script:StepPath.RemoveAt($script:StepPath.Count - 1)
        if ($script:StepPath.Count -gt 0) {
            $script:StepStatusContext.Status = Format-StepStatus   # restore the parent's breadcrumb
        }
    }
}

function Format-StepStatus {
    <#
    .SYNOPSIS
        Renders the $script:StepPath breadcrumb as spinner status text.

    .DESCRIPTION
        Markup-escapes each segment (doubling [ and ] so step text can't be parsed as Spectre
        markup tags), joins them with ›, and prefixes the top-level step's icon.

    .EXAMPLE
        Format-StepStatus   # e.g. "🔩 Tools › fnm › Install"
    #>
    $segments = $script:StepPath | ForEach-Object { Get-SpectreEscapedTextSafe $_ }
    return "$(Get-StepIconPrefix $script:StepRootIcon)$($segments -join ' › ')"
}
