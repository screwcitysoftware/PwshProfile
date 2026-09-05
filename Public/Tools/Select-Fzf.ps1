function Select-Fzf {
    <#
    .SYNOPSIS
        Pipes objects through fzf for interactive fuzzy selection and returns the chosen object(s) —
        not text you have to re-parse.

    .DESCRIPTION
        A general-purpose fzf wrapper that replaces hand-rolled pipelines like:

            Get-AzSubscription | % { "{0}`t{1}" -f $_.Name, $_.Id } |
              fzf --with-nth 1 --nth 1 --accept-nth 2 --delimiter "`t" --height=~100%

        Pipe in any objects, say what to display (-Display) and optionally what to return (-Value),
        and Select-Fzf hands back the live selected object(s).

        The mechanism, which is what keeps it robust for arbitrary objects and arbitrary display text:
          - Each item is tagged with a hidden integer index and rendered as "<index><US><display>",
            joined by ASCII Unit Separator (0x1f) — a non-printable delimiter that can't collide with
            display text, so tabs and colons in the display survive. Only newlines are collapsed, since
            one would split an item across lines.
          - fzf runs with --delimiter=<US> --with-nth=2.., so the display column is the only thing shown
            AND the only thing searched, while the index stays hidden. (No --nth: it indexes the
            post---with-nth view, not the original line.) fzf still emits the full original line on
            selection, so the index is recovered and mapped back to the original object.
          - That object is returned as-is, or -Value projects a property or computed value from it.

        fzf is invoked with --ansi and inherits $env:FZF_DEFAULT_OPTS, so once Enable-Fzf has themed
        fzf the picker matches the prompt with no wiring here. A missing fzf.exe warns; an empty
        pipeline, an Esc cancel, and a no-match all return nothing. It never throws.

    .PARAMETER InputObject
        The objects to choose from, supplied via the pipeline or as an array argument.

    .PARAMETER Display
        What to show for each item: a property name, or a scriptblock receiving the item as $_ (e.g.
        { "{0} ({1})" -f $_.Name, $_.Id }). Defaults to the item's string representation. The resolved
        text is the only thing shown and the only thing fzf searches.

    .PARAMETER Value
        What to return for the selected item(s): a property name or a scriptblock ($_ = the item).
        Defaults to the whole original object, so .Property still works on the result.

    .PARAMETER Multiple
        Enables fzf's multi-select (Tab/Shift+Tab to mark rows). The result is always an array, which
        may be empty if nothing was marked.

    .PARAMETER Prompt
        Text for fzf's input prompt, e.g. 'subscription> '. Empty leaves fzf's default.

    .PARAMETER Header
        A sticky header line shown above the list. Empty shows no header.

    .PARAMETER Height
        fzf's --height value. Defaults to '~100%' (adaptive: fills the shell for long lists, shrinks to
        fit short ones), matching the module convention. Set to '' for fzf's own default.

    .PARAMETER FzfArgument
        Escape hatch: extra raw arguments appended verbatim to the fzf invocation (e.g. '--cycle'),
        for anything not surfaced as a dedicated parameter.

    .EXAMPLE
        Get-ChildItem | Select-Fzf -Display Name

        Fuzzy-pick a file or directory by name; returns the selected FileInfo/DirectoryInfo object.

    .EXAMPLE
        Get-AzSubscription | Select-Fzf -Display Name -Value Id

        The robust replacement for the hand-rolled example above: shows names, returns the chosen Id.

    .EXAMPLE
        Get-Process | Select-Fzf -Display { "{0} ({1})" -f $_.Name, $_.Id } -Multiple -Prompt 'kill> '

        Multi-select with a computed display; returns an array of the chosen Process objects.

    .NOTES
        Requires fzf on PATH (see Enable-Fzf). The fzf invocation is isolated in the private
        Invoke-FzfRaw helper below so this function's mapping logic is unit-testable.
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
        [string]$Prompt,

        [Parameter()]
        [string]$Header,

        [Parameter()]
        [string]$Height = '~100%',

        [Parameter()]
        [string[]]$FzfArgument = @()
    )

    begin {
        $items = [System.Collections.Generic.List[object]]::new()
    }

    process {
        # $InputObject is [object[]], so a single piped item arrives as a 1-element array — flatten so
        # the index scheme tracks individual objects whether piped or passed as an array.
        if ($null -ne $InputObject) {
            foreach ($item in $InputObject) { $items.Add($item) }
        }
    }

    end {
        if ($items.Count -eq 0) { return }

        # Resolve a property name or scriptblock ($_ = item) against an item. A $null selector means
        # no projection: display falls back to the item's string form, value to the item itself.
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
        # delimiter that can't collide with display text the way a tab or ':' could. Only newlines are
        # collapsed, since one would split an item across multiple fzf lines.
        $delim = [char]0x1f
        $lines = for ($i = 0; $i -lt $items.Count; $i++) {
            $text = "$(& $resolve $items[$i] $Display $true)" -replace "[`r`n$delim]", ' '
            "$i$delim$text"
        }

        $fzfArgs = [System.Collections.Generic.List[string]]::new()
        $fzfArgs.Add('--ansi')
        $fzfArgs.Add("--delimiter=$delim")
        # --with-nth=2.. both displays and searches only the text column, hiding the index from the
        # picker and from matching. No --nth: it indexes the --with-nth view, so --nth=2 would point
        # past the single field there and match nothing.
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

        # Under -Multiple always hand back an array, as the help and README promise. The unary comma is
        # required: a bare @(...) is unrolled by the pipeline, collapsing a one-element result to a
        # scalar. Single-select stays a scalar so `.Property` keeps working.
        if ($Multiple) { return , @($results) }
        $results
    }
}

# Co-located here rather than in Private/ so Select-Fzf stays a single portable file. It is not
# exported (the loader exports only Public file base names, and it isn't in the manifest), and it
# isolates the one native fzf call so Select-Fzf's mapping logic stays unit-testable — Pester can't
# mock a native fzf.exe invocation. It also centralizes failure tolerance: a missing fzf.exe, a cancel
# (exit 130), and a no-match (exit 1) all surface as no output rather than an error.
function Invoke-FzfRaw {
    <#
    .SYNOPSIS
        Pipes a set of input lines through fzf and returns the lines the user selected.

    .DESCRIPTION
        The thin, failure-tolerant seam between Select-Fzf and the fzf executable: feeds $InputLine to
        `fzf.exe @Argument` on stdin and returns its stdout as a string array.

        It is a separate, mockable function for two reasons. It isolates the one native-command call so
        Select-Fzf's object-mapping logic can be unit-tested (Pester can mock neither an interactive fzf
        nor a native fzf.exe invocation), and it centralizes the module's failure tolerance: a missing
        fzf.exe, a cancel (exit 130), and a no-match (exit 1) all surface as no output rather than an
        error. It lives in this file rather than Private/ so Select-Fzf stays portable as a single unit.

    .PARAMETER InputLine
        The candidate lines to present to fzf on stdin, one per line. Empty input yields no output.

    .PARAMETER Argument
        The raw argument array splatted verbatim to fzf.exe — the caller owns argument construction.

    .EXAMPLE
        $us = [char]0x1f
        Invoke-FzfRaw -InputLine "0${us}apple", "1${us}banana" -Argument "--delimiter=$us", '--with-nth=2..'

        Shows "apple"/"banana" with the index column hidden, and returns the full selected line.

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
        # Pipe candidates to fzf on stdin; its stdout is the selection. A cancel (130) or no-match (1)
        # yields no stdout — treated as "nothing selected", never an error.
        $selected = $InputLine | & fzf.exe @Argument
        if ($null -eq $selected) { return @() }
        return @($selected)
    }
    catch {
        return @()
    }
}
