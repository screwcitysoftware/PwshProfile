$script:StepStatusContext = $null   # Spectre [StatusContext] while a top-level step's spinner is active
$script:StepPath          = [System.Collections.Generic.List[string]]::new()  # breadcrumb of running step descriptions
$script:StepRootIcon      = ''    # icon of the current top-level step, prefixes the breadcrumb
$script:StepWarnings      = [System.Collections.Generic.List[System.Management.Automation.WarningRecord]]::new()  # warnings captured during the live spinner, replayed after it clears

function Invoke-Step {
    <#
    .SYNOPSIS
        Runs a named startup step, showing the current stage in a status spinner and a
        per-top-level-step summary line.

    .DESCRIPTION
        Invokes the supplied script block and renders it through PwshSpectreConsole.

        The first (top-level) call opens a transient status spinner and stashes its
        [Spectre.Console.StatusContext] in the module-scoped $script:StepStatusContext. Nested calls
        see that context and only push their description onto the $script:StepPath breadcrumb,
        updating the spinner text to the full path (e.g. "🔩 WinGet › fnm › Install") and restoring
        the parent's breadcrumb when they finish. Only the top-level step's icon is shown.

        When the top-level step completes, the spinner clears itself and a single summary line is
        written with the total elapsed time:

            🔩 Completions...................................... [ 352ms]

        Nested substeps leave no output of their own.

        A Write-Warning raised inside a step would be torn off-screen when the spinner clears, so the
        top-level call captures the body's warning stream instead of letting it paint, then re-emits
        the warnings once the spinner is gone and the summary line is written. They persist in
        scrollback, grouped under the top-level step — which is why a warning appears after its
        summary line rather than inline.

        The body's pipeline output is discarded. An exception propagates out of Invoke-Step and
        suppresses the summary line, but the module-scoped state is restored in finally blocks so a
        failing step cannot wedge later ones, and warnings captured before the throw are still
        replayed. If PwshSpectreConsole is unavailable the body still runs, silently and unrendered,
        so startup never fails over presentation.

    .PARAMETER Description
        The text shown for the step, e.g. "Completions". Required.

    .PARAMETER ScriptBlock
        The script block to run. Nested Invoke-Step calls may appear inside it. Required.

    .PARAMETER Icon
        The marker printed before the description — a Spectre emoji shortcode, default
        ':nut_and_bolt:'. It carries no trailing space; the separator is added at render time by
        Get-StepIconPrefix. Only the top-level step's icon is shown.

    .EXAMPLE
        Invoke-Step "Initialize PSReadLine" { Import-Module PSReadLine }

        Shows "🔩 Initialize PSReadLine" beside a spinner while it runs, then prints:
        🔩 Initialize PSReadLine.................................. [  42ms]

    .EXAMPLE
        Invoke-Step "Completions" {
            Invoke-Step "Tailscale" { }
            Invoke-Step "Azure"     { Invoke-Step "Subscriptions" { } }
        }

        Runs nested steps. The spinner walks the breadcrumb, clears when done, and prints a single
        summary line for "Completions".

    .NOTES
        Module-scoped state lives in this file's private scope, initialized once at import:
        - $script:StepStatusContext is the renderer's invariant — the top-level call owns the spinner
          and the context; nested calls see it and only update its Status.
        - $script:StepPath is the breadcrumb stack; $script:StepRootIcon is the top-level icon that
          prefixes it.
        - $script:StepWarnings accumulates warnings captured during the live spinner.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Description,
        [Parameter(Mandatory)]
        [ScriptBlock]$ScriptBlock,
        [Parameter()]
        [string]$Icon = ':nut_and_bolt:'
    )

    # Failure tolerance: without Spectre the step still runs, just unrendered.
    if (-not (Get-Command Invoke-SpectreCommandWithStatus -ErrorAction SilentlyContinue)) {
        $null = & $ScriptBlock   # nested Invoke-Step calls inside hit this same guard
        return
    }

    # Top-level call: open the status spinner, stash its context for nested calls, run this step inside
    # it, then print the summary line. The scriptblock must stay a plain literal so $script: binds to
    # this module's scope — .GetNewClosure() rebinds those writes to a throwaway dynamic module and
    # silently breaks the stash. Swallow the result: the helper emits $null even for a void block.
    if ($null -eq $script:StepStatusContext) {
        # Warnings painted into the live spinner are torn off-screen when it clears, so capture them
        # (3>&1, below) and replay them after. Reset the accumulator for this top-level step.
        $script:StepWarnings.Clear()
        $label = Get-SpectreEscapedTextSafe ((Get-StepIconPrefix $Icon) + $Description)
        # PwshSpectreConsole resolves the inner block's free variables dynamically, so hold the body in
        # a distinctly-named local that the invoker's own -ScriptBlock parameter can't shadow.
        $stepBody = $ScriptBlock
        try {
            $elapsed = Measure-Command {
                $null = Invoke-SpectreCommandWithStatus -Title $label -ScriptBlock {
                    # A [Spectre.Console.StatusContext]; left untyped so tests can inject a fake.
                    param($Context)
                    $script:StepStatusContext = $Context
                    try {
                        # 3>&1 keeps the body's warnings out of the live spinner; the WarningRecord
                        # guard stops non-warning output from leaking into the pipeline.
                        Invoke-StepInternal -Description $Description -ScriptBlock $stepBody -Icon $Icon 3>&1 |
                            ForEach-Object { if ($_ -is [System.Management.Automation.WarningRecord]) { $script:StepWarnings.Add($_) } }
                    }
                    finally {
                        $script:StepStatusContext = $null
                        $script:StepPath.Clear()
                    }
                }
            }

            # The spinner has cleared itself — leave one permanent line with the total elapsed
            # time. A throwing step never reaches this (exceptions propagate out of Measure-Command).
            $ms = $elapsed.TotalMilliseconds.ToInt32([cultureinfo]::InvariantCulture).ToString('d').PadLeft(4, ' ')
            $dots = '.' * [Math]::Max(0, 50 - $Description.Length)   # 50-char budget for description + dots
            $escapedIcon = Get-SpectreEscapedTextSafe (Get-StepIconPrefix $Icon)
            $escapedDescription = Get-SpectreEscapedTextSafe $Description
            Write-SpectreHost "[yellow]$escapedIcon[/]$escapedDescription[grey]$dots[/] [yellow][[$($ms)ms]][/]"
        }
        finally {
            # Replay captured warnings now that the spinner (and summary line) are written, so
            # they persist in scrollback. The finally surfaces them even if the step threw.
            foreach ($w in $script:StepWarnings) { Write-Warning $w.Message }
            $script:StepWarnings.Clear()
        }
        return
    }

    # Nested call: a spinner is already open — just walk the breadcrumb.
    Invoke-StepInternal -Description $Description -ScriptBlock $ScriptBlock -Icon $Icon
}
