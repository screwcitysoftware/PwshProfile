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
        Invokes the supplied script block and renders it through PwshSpectreConsole:

        - While running, the first (top-level) call opens a transient status spinner and
          stashes its [Spectre.Console.StatusContext] in the module-scoped
          $script:StepStatusContext. Nested calls push their description onto the
          $script:StepPath breadcrumb and update the spinner text to the full path (e.g.
          "🔩 WinGet › fnm › Install"), restoring the parent's breadcrumb when they finish.
          Only the top-level step's icon is shown (nested custom icons don't appear).

        - When the top-level step completes, the spinner clears itself and a single summary
          line is written with the step's total elapsed time, e.g.:
          🔩 Completions...................................... [ 352ms]
          Nested substeps leave no output of their own.

        If PwshSpectreConsole isn't available, the step body still runs — silently, with no
        rendering — so profile startup never fails over presentation.

        A Write-Warning raised inside a step would otherwise be torn off-screen when the live
        spinner clears itself. To keep warnings readable, the top-level call captures the body's
        warning stream (including warnings from any nested steps) instead of letting it paint,
        then re-emits the captured warnings after the spinner has cleared and the summary line is
        written — so they persist in scrollback, grouped under the top-level step's summary line.

        The step body's pipeline output is discarded. An exception thrown by the body
        propagates out of Invoke-Step (and suppresses the summary line); the module-scoped
        state is restored in finally blocks so a failing step cannot wedge later steps, and any
        warnings captured before the throw are still replayed.

    .PARAMETER Description
        The text shown for the step (e.g. "Completions"). Required.

    .PARAMETER ScriptBlock
        The script block to run. Nested Invoke-Step calls may appear inside it. Required.

    .PARAMETER Icon
        The marker printed before the description. Defaults to ':nut_and_bolt:' (a Spectre
        emoji shortcode, rendered as 🔩). The separating space between the icon and the text is
        added at render time (via Get-StepIconPrefix), so the value itself carries no trailing
        space. Only the top-level step's icon is shown in the spinner and the summary line.

    .EXAMPLE
        Invoke-Step "Initialize PSReadLine" { Import-Module PSReadLine }

        Shows "🔩 Initialize PSReadLine" beside a spinner while it runs, then prints:
        🔩 Initialize PSReadLine.................................. [  42ms]

    .EXAMPLE
        Invoke-Step "Completions" {
            Invoke-Step "Tailscale" { }
            Invoke-Step "Azure"     { Invoke-Step "Subscriptions" { } }
        }

        Runs nested steps. The spinner walks the breadcrumb ("🔩 Completions",
        "🔩 Completions › Tailscale", "🔩 Completions › Azure › Subscriptions", …), clears when
        done, and a single summary line is printed for "Completions".

    .NOTES
        Module-scoped state lives in this module's private scope, initialized once at import:
        - $script:StepStatusContext is the renderer's invariant: the top-level call owns the
          spinner and the context; nested calls see it and only update its Status.
        - $script:StepPath is the breadcrumb stack of running step descriptions;
          $script:StepRootIcon is the top-level step's icon that prefixes the breadcrumb.
        - $script:StepWarnings accumulates warnings captured during the live spinner; the
          top-level call replays them after the spinner clears so they survive in scrollback.
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
