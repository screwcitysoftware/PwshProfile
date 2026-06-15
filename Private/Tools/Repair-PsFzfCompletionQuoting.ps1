function Repair-PsFzfCompletionQuoting {
    <#
    .SYNOPSIS
        Trims the trailing "completion-complete" space from PSFzf's quoting helper so
        fuzzy-completion candidates insert unquoted.

    .DESCRIPTION
        PSFzf's Invoke-FzfTabCompletion runs every candidate through its module-internal
        FixCompletionResult helper, which double-quotes any candidate containing whitespace —
        including a meaningless *trailing* space. Many completers append exactly such a trailing
        space to a candidate's CompletionText as the conventional "this token is complete" marker:
        argcomplete (`az`, with _ARGCOMPLETE_SUPPRESS_SPACE=0), Cobra CLIs in MenuComplete mode
        (`gh`/`tailscale`/`op`), and winget. The result is that selecting `account` inserts
        `"account "` instead of `account ` (completers that emit no trailing space, like posh-git's
        git completer, are unaffected and already insert cleanly).

        This re-defines FixCompletionResult inside PSFzf's own module session state with a copy
        that TrimEnd()s before the quote decision, so the trailing space is dropped and the
        candidate is no longer needlessly quoted. PSFzf re-adds a single trailing space after
        selection, so completions insert as `az account `. Interior spaces are untouched, so a
        real path like `Program Files` is still quoted correctly. The trim is also harmless at
        FixCompletionResult's other call sites (the Ctrl+T file picker), since file paths never
        end in a semantically meaningful space.

        Guarded and failure-tolerant per the module's design rules: it is a no-op when PSFzf is
        not loaded, and bails if a future PSFzf no longer exposes FixCompletionResult. It is
        idempotent — safe to call on every reload.

    .EXAMPLE
        Import-ModuleSafe PSFzf
        Repair-PsFzfCompletionQuoting

        After PSFzf is imported, patches its FixCompletionResult so external-CLI fuzzy
        completions (gh/az/winget/…) insert unquoted.

    .NOTES
        Get-Module is the correct cmdlet here (not a PSResourceGet availability check): it returns
        the *live, loaded* PSModuleInfo whose session state the `& $module { … }` call defines the
        replacement function into. Get-InstalledPSResource returns package metadata with no
        invokable session state and cannot drive this injection. This mirrors the project's own
        `& (Get-Module $module) { … }` idiom.
    #>
    [CmdletBinding()]
    param()

    $module = Get-Module PSFzf
    if (-not $module) { return }

    if (-not (& $module { Get-Command FixCompletionResult -CommandType Function -ErrorAction SilentlyContinue })) {
        return
    }

    & $module {
        function script:FixCompletionResult($str, [switch]$AlwaysQuote) {
            if ([string]::IsNullOrEmpty($str)) { return '' }
            # TrimEnd drops the trailing "completion-complete" space some completers append
            # (argcomplete SUPPRESS_SPACE=0, Cobra MenuComplete, winget); interior spaces are
            # left intact, so real paths like "Program Files" are still quoted below.
            $str = $str.Replace("`r`n", '').TrimEnd()
            $isAlreadyQuoted = ($str.StartsWith("'") -and $str.EndsWith("'")) -or `
                ($str.StartsWith('"') -and $str.EndsWith('"'))
            if ($isAlreadyQuoted) { return $str }
            if ($AlwaysQuote -or $str.Contains(' ') -or $str.Contains("`t")) { return '"{0}"' -f $str }
            else { return $str }
        }
    }
}
