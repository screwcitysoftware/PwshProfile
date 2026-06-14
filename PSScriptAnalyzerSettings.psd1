@{
    # Lint Public/ and Private/ for real defects. Errors and Warnings fail the build
    # (see build.ps1 -Task Analyze); Information-level rules are advisory only.
    Severity     = @('Error', 'Warning')

    ExcludeRules = @(
        # The module deliberately defines `function global:` helpers and runs tool init
        # text in the global scope (Invoke-InGlobalScope) — that is the documented
        # mechanism for landing completions/aliases in the true global scope, not an
        # accident. This rule would flag every such helper.
        'PSAvoidGlobalVars'

        # Enable-*/Set-*/Install-* enablers intentionally do not implement -WhatIf:
        # they are profile-startup side effects guarded by Get-Command, and the module's
        # design rule is failure-tolerance, not ShouldProcess ceremony.
        'PSUseShouldProcessForStateChangingFunctions'

        # The module is deliberately UTF-8 *without* a BOM (the .psm1 forces UTF-8 console
        # encoding); BOM-less UTF-8 is the cross-platform, git-friendly norm for pwsh 7.4+.
        # This rule would demand a BOM on every file containing emoji / box-drawing glyphs.
        'PSUseBOMForUnicodeEncodedFile'

        # High false-positive rate here: it does not see parameters used only inside nested
        # scriptblocks (e.g. $Configuration inside `Invoke-Step "Initialize" { ... }`), and it
        # flags the fixed ArgumentCompleter signature params (commandName/parameterName/
        # commandAst/fakeBoundParameters) that the completer contract requires.
        'PSReviewUnusedParameter'
    )
}
