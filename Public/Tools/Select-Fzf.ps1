function Select-Fzf {
    <#
    .SYNOPSIS
        Pipes objects through fzf for interactive fuzzy selection and returns the chosen object(s) —
        not text you have to re-parse.

    .DESCRIPTION
        A general-purpose wrapper over fzf that replaces hand-rolled one-off pipelines like:

            Get-AzSubscription | % { "{0}`t{1}" -f $_.Name, $_.Id } |
              fzf --with-nth 1 --nth 1 --accept-nth 2 --delimiter "`t" --height=~100%

        Pipe in ANY objects, say what to display (-Display) and optionally what to return (-Value),
        and Select-Fzf hands back the live selected object(s).

        How it works (so it stays robust for arbitrary objects and arbitrary display text):
          - Each piped item is tagged with a hidden integer index and rendered as an
            "<index><US><display>" line, joined by ASCII Unit Separator (0x1f) — a non-printable
            control char that can't collide with human-readable display text, so the display keeps its
            tabs/colons/etc. Only newlines (which would split one item across lines) are collapsed.
          - fzf runs with --delimiter=<US> --with-nth=2.., so only the display column is shown AND
            searched (--with-nth scopes both), while the index column stays hidden and unsearchable.
            (No --nth: it would index the post---with-nth view, not the original line.) fzf still emits
            the FULL original line on selection, so the leading index is recovered and mapped back to
            the original object.
          - The matching object is returned as-is, or -Value projects a property/computed value from it.

        Theme & failure tolerance:
          - fzf is invoked with --ansi, and it inherits $env:FZF_DEFAULT_OPTS — so when Enable-Fzf has
            themed fzf, the picker matches the prompt palette automatically (no extra wiring here).
          - If fzf.exe isn't on PATH a warning is emitted and nothing is returned; an empty pipeline,
            an Esc cancel, or a no-match all return nothing. It never throws.

    .PARAMETER InputObject
        The objects to choose from, supplied via the pipeline (or as an array argument).

    .PARAMETER Display
        What to show for each item: either a property NAME (string) or a SCRIPTBLOCK that receives the
        item as $_ and returns the row text (e.g. { "{0} ({1})" -f $_.Name, $_.Id }). When omitted, the
        item's string representation ("$item") is used. The resolved text is the only thing shown and
        the only thing fzf searches.

    .PARAMETER Value
        What to return for the selected item(s): a property NAME (string) or a SCRIPTBLOCK ($_ = the
        item). When omitted, the whole original object is returned — the most flexible default
        (.Property still works on the result).

    .PARAMETER Multiple
        Enables fzf's multi-select (--multi: Tab/Shift+Tab to mark rows). The result is an array of the
        selected values (which may be empty if nothing was marked).

    .PARAMETER Prompt
        Text for fzf's input prompt (fzf --prompt), e.g. 'subscription> '. Empty leaves fzf's default.

    .PARAMETER Header
        A sticky header line shown above the list (fzf --header). Empty shows no header.

    .PARAMETER Height
        fzf's --height value. Defaults to '~100%' (adaptive: fills the shell for long lists, shrinks to
        fit short ones), matching the module convention. Set to '' to let fzf use its own default.

    .PARAMETER FzfArgument
        Escape hatch: extra raw arguments appended verbatim to the fzf invocation (e.g.
        '--cycle', '--border'), for anything not surfaced as a dedicated parameter.

    .EXAMPLE
        Get-ChildItem | Select-Fzf -Display Name

        Fuzzy-pick a file/directory by name; returns the selected FileInfo/DirectoryInfo object.

    .EXAMPLE
        Get-AzSubscription | Select-Fzf -Display Name -Value Id

        The robust replacement for the hand-rolled example: shows subscription names, returns just the
        selected subscription's Id.

    .EXAMPLE
        Get-Process | Select-Fzf -Display { "{0} ({1})" -f $_.Name, $_.Id } -Multiple -Prompt 'kill> '

        Multi-select processes with a computed "Name (Id)" display; returns an array of the chosen
        Process objects.

    .NOTES
        Requires fzf on PATH (see Enable-Fzf). The actual fzf invocation is isolated in the private
        Invoke-FzfRaw helper so this function's mapping logic is unit-testable.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [object[]]$InputObject,

        [Parameter(Position = 0)]
        [object]$Display,

        [Parameter()]
        [object]$Value,

        [Parameter()]
        [switch]$Multiple,

        [Parameter()]
        [string]$Prompt = '',

        [Parameter()]
        [string]$Header = '',

        [Parameter()]
        [string]$Height = '~100%',

        [Parameter()]
        [string[]]$FzfArgument = @()
    )

    begin {
        $items = [System.Collections.Generic.List[object]]::new()
    }

    process {
        # $InputObject is [object[]], so a single piped item arrives as a 1-element array; flatten so
        # the index/line scheme tracks individual objects whether piped or passed as an array argument.
        if ($null -ne $InputObject) {
            foreach ($item in $InputObject) { $items.Add($item) }
        }
    }

    end {
        if ($items.Count -eq 0) { return }

        # Resolve a property-name string or a scriptblock ($_ = item) against an item. A $null
        # selector means "no projection": the display falls back to the item's string form, the value
        # to the item itself.
        $resolve = {
            param($item, $selector, $forDisplay)
            if ($null -eq $selector) {
                if ($forDisplay) { return "$item" } else { return $item }
            }
            if ($selector -is [scriptblock]) {
                return $item | ForEach-Object $selector
            }
            return $item.$selector
        }

        # Join a hidden index and the display text with ASCII Unit Separator (0x1f) — a non-printable
        # control char built for delimiting machine fields, so it can't collide with human-readable
        # display text (unlike a tab or ':'). Only newlines (and a stray US char) are collapsed, since
        # a newline would split one item across multiple fzf lines; tabs/colons in the display survive.
        $delim = [char]0x1f
        $lines = for ($i = 0; $i -lt $items.Count; $i++) {
            $text = "$(& $resolve $items[$i] $Display $true)" -replace "[`r`n$delim]", ' '
            "$i$delim$text"
        }

        $fzfArgs = [System.Collections.Generic.List[string]]::new()
        $fzfArgs.Add('--ansi')
        $fzfArgs.Add("--delimiter=$delim")
        # --with-nth=2.. both DISPLAYS and SEARCHES only the text column, hiding the index from the
        # picker and excluding it from matching. No --nth: fzf's --nth indexes the *--with-nth view*
        # (a single field here), so adding --nth=2 would point past it and match nothing.
        $fzfArgs.Add('--with-nth=2..')
        if (-not [string]::IsNullOrWhiteSpace($Height))  { $fzfArgs.Add("--height=$Height") }
        if ($Multiple)                                   { $fzfArgs.Add('--multi') }
        if (-not [string]::IsNullOrEmpty($Prompt))       { $fzfArgs.Add("--prompt=$Prompt") }
        if (-not [string]::IsNullOrEmpty($Header))       { $fzfArgs.Add("--header=$Header") }
        if ($FzfArgument)                                { $fzfArgs.AddRange([string[]]$FzfArgument) }

        $selected = Invoke-FzfRaw -InputLine $lines -Argument $fzfArgs
        if (-not $selected) { return }

        $results = foreach ($line in $selected) {
            # Recover the hidden leading index and map back to the original object.
            $idx = ($line -split [regex]::Escape($delim), 2)[0] -as [int]
            if ($null -eq $idx -or $idx -lt 0 -or $idx -ge $items.Count) { continue }
            & $resolve $items[$idx] $Value $false
        }

        # Under -Multiple always hand back an array (even for a single marked row), as the help and
        # README promise. The unary comma is required: a bare `@(...)` would be unrolled by the
        # pipeline on the way out, collapsing a one-element result back to a scalar at the call site.
        # Single-select stays a scalar so `.Property` keeps working on the result.
        if ($Multiple) { return , @($results) }
        $results
    }
}

# Invoke-FzfRaw is co-located here (not in Private/) on purpose: it keeps Select-Fzf a single,
# self-contained file that can be lifted into another module without dragging a sibling helper. It is
# NOT exported (the .psm1 loader exports only Public *file* base names, and it isn't in the manifest),
# so it stays an internal seam. That seam isolates the one native fzf call so Select-Fzf's mapping
# logic can be unit-tested by mocking it (Pester can't mock a native fzf.exe invocation), and it
# centralizes the module's failure tolerance — a missing fzf.exe, a cancel (exit 130), or a no-match
# (exit 1) all surface as no output rather than an error, so nothing throws.
function Invoke-FzfRaw {
    <#
    .SYNOPSIS
        Pipes a set of input lines through fzf and returns the lines the user selected.

    .DESCRIPTION
        The thin, failure-tolerant seam between Select-Fzf and the fzf executable. It feeds
        $InputLine to `fzf.exe @Argument` on stdin and returns fzf's stdout (the selected line(s))
        as a string array.

        It is a separate (mockable) function for two reasons:
          - It isolates the one native-command invocation, so Select-Fzf's object-mapping logic can
            be unit-tested by mocking this function (an interactive fzf can't run under Pester, and
            Pester can't mock a native fzf.exe call either).
          - It centralizes the failure tolerance the module requires: a missing fzf.exe, a cancel
            (Esc / Ctrl+C, exit 130), or "no match" (exit 1) all surface as no output rather than an
            error, so nothing throws.

        It lives in this file rather than Private/ so Select-Fzf stays portable as a single unit; it is
        still internal (not exported). Mirrors the pattern of Get-FzfVersion (Get-Command guard, never
        throws, returns a benign empty result on any failure).

    .PARAMETER InputLine
        The lines to present to fzf on stdin (one candidate per line). Empty/no input yields no
        output (fzf would just present an empty list).

    .PARAMETER Argument
        The raw argument array passed to fzf.exe (e.g. '--multi', '--with-nth=2..', a '--delimiter=...').
        Splatted verbatim — the caller owns argument construction.

    .EXAMPLE
        $us = [char]0x1f
        Invoke-FzfRaw -InputLine "0${us}apple", "1${us}banana" -Argument "--delimiter=$us", '--with-nth=2..'

        Shows "apple"/"banana" (index column hidden) and returns the full selected line, e.g. "1<US>banana"
        (Select-Fzf joins its index/display columns with ASCII Unit Separator, 0x1f).

    .NOTES
        fzf writes the FULL original input line to stdout on selection regardless of --with-nth (which
        only affects display), which is what lets the caller recover a hidden index column.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter()]
        [string[]]$InputLine = @(),

        [Parameter()]
        [string[]]$Argument = @()
    )

    if (-not (Get-Command fzf.exe -ErrorAction SilentlyContinue)) {
        Write-Warning 'Select-Fzf: fzf.exe is not on PATH. Run Enable-Fzf (or install fzf) first.'
        return @()
    }

    if ($InputLine.Count -eq 0) { return @() }

    try {
        # Pipe candidates to fzf on stdin; its stdout is the selection (one line per chosen item).
        # A cancel (exit 130) or no-match (exit 1) simply yields no stdout — treated as "nothing
        # selected", never an error.
        $selected = $InputLine | & fzf.exe @Argument
        if ($null -eq $selected) { return @() }
        return @($selected)
    }
    catch {
        return @()
    }
}
