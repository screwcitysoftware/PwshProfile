# The engine's top-level (global) session state, resolved once at import. Tool-init scripts (zoxide,
# oh-my-posh, fnm, xh, Cobra completions) run against this so the functions and aliases they emit land
# in the real global scope. A plain Invoke-Expression from a module function tags everything it defines
# to the module — even `function global:` ones — which is what leaked __zoxide_* and the completion
# helpers into `Get-Command -Module ScrewCitySoftware.PwshProfile`. Reached by reflection since it is
# engine-private; $null means "couldn't resolve", and Invoke-InGlobalScope then falls back to a plain
# Invoke-Expression so a future pwsh build moving these internals can never break startup.
$script:GlobalSessionState = $null
try {
    $flags = [System.Reflection.BindingFlags]'NonPublic, Instance'
    $context = $ExecutionContext.GetType().GetField('_context', $flags).GetValue($ExecutionContext)
    $topSessionState = $context.GetType().GetProperty('TopLevelSessionState', $flags).GetValue($context)
    $script:GlobalSessionState = $topSessionState.GetType().GetProperty('PublicSessionState', $flags).GetValue($topSessionState)
}
catch {
    $script:GlobalSessionState = $null
}

function Invoke-InGlobalScope {
    <#
    .SYNOPSIS
        Runs a script string in the engine's top-level (global) scope, unattributed to this module.

    .DESCRIPTION
        Tool integrations (zoxide, oh-my-posh, fnm, xh, Cobra completions) hand back a script of
        function/alias definitions meant to be Invoke-Expressed at the profile's global scope. When
        a module function Invoke-Expresses that text directly, PowerShell tags every function it
        defines with the module's name — even `function global:` ones — so they leak into
        `Get-Command -Module ScrewCitySoftware.PwshProfile`. This helper instead executes the script
        against the engine's top-level session state ($script:GlobalSessionState, resolved once at
        import), so the definitions land in the true global scope with no module attribution, exactly
        as if the user had run the init line themselves at the prompt.

        If the global session state couldn't be resolved (reflection into engine internals failed),
        it falls back to a plain Invoke-Expression: the init still runs, its helpers are just tagged
        to the module again. Failure tolerance — this must never throw out of profile startup.

    .PARAMETER Expression
        The script text to execute (typically a tool's init/completion output piped through
        Out-String).

    .EXAMPLE
        Invoke-InGlobalScope (zoxide init powershell --cmd cd | Out-String)

    .NOTES
        Use this for any tool-init output that defines functions or aliases the user calls later from
        the prompt; it replaces the older `function __` -> `function global:__` textual rewrite, since
        running in global scope makes such helpers global without rewriting the source.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '',
        Justification = 'Intentional degraded fallback: this helper exists to execute trusted tool-init script text in the global scope; Invoke-Expression is the documented path used only when reflecting the engine''s top-level session state fails.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Expression
    )

    if ($script:GlobalSessionState) {
        $ExecutionContext.InvokeCommand.InvokeScript($script:GlobalSessionState, [scriptblock]::Create($Expression), $null)
    }
    else {
        Invoke-Expression $Expression
    }
}
