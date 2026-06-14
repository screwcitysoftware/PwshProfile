function Format-PwshProfileHelpMarkup {
    <#
    .SYNOPSIS
        Converts a light, markdown-ish help string into safe Spectre markup with two-color
        highlighting for the Install-PwshProfile wizard.

    .DESCRIPTION
        The single source of truth for how the install wizard highlights its description text. Authors
        write help strings in a small convention and this function emits the Spectre markup the prompt
        helpers render, so tool names and code literals stand out from the body prose instead of being
        a flat grey wall:

          **term**   →  the term in the accent color   (tool / product names, e.g. **oh-my-posh**)
          `code`     →  the code in the code color      (file types, commands, paths, e.g. `.omp.json`)
          anything else  →  escaped and left in the body color

        Everything outside the two token kinds — and the token contents themselves — is escaped via
        Get-SpectreEscapedText (so authored text containing '[' or ']' is safe), then the whole line
        is wrapped in the body style. Spectre resolves nested styles with a stack, so an accent or code
        span inside the body wrapper correctly reverts to the body color after it closes.

        If Get-SpectreEscapedText is unavailable (Spectre not loaded), it falls back to doubling the
        bracket characters by hand, matching the module's degrade-don't-throw rule.

    .PARAMETER Text
        The help string to format. May be empty. Use **...** for tool/product names and `...` for code
        literals; all other characters are treated as plain body text.

    .PARAMETER Accent
        The color for **...** spans, as a Spectre color name or hex value. Defaults to the module's
        signature purple (#c9aaff).

    .PARAMETER Code
        The color for `...` spans, as a Spectre color name or hex value. Defaults to a soft cyan
        (#5fd7ff).

    .PARAMETER Body
        The style wrapping the plain body text, as a Spectre color/style name or hex value. Defaults to
        'grey'. Pass 'default' (or an empty string) to leave the body in the terminal's default color
        with no wrapper — useful when the surrounding context already sets a color.

    .EXAMPLE
        Format-PwshProfileHelpMarkup -Text 'Use **zoxide** by typing `cd` to jump.'

        Returns '[grey]Use [#c9aaff]zoxide[/] by typing [#5fd7ff]cd[/] to jump.[/]'.

    .EXAMPLE
        Format-PwshProfileHelpMarkup -Text 'custom: **forestcity**' -Body default

        Returns '[#c9aaff]forestcity[/]' prefixed by the escaped 'custom: ', with no grey wrapper —
        the value sits in the surrounding (default) color.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter()]
        [string]$Accent = '#c9aaff',

        [Parameter()]
        [string]$Code = '#5fd7ff',

        [Parameter()]
        [string]$Body = 'grey'
    )

    # Escape a plain run for Spectre markup (prefer the real escaper; fall back to doubling brackets).
    $escape = { param($s) Get-SpectreEscapedTextSafe -Text "$s" }

    # Match **brand** or `code`, non-greedily, so adjacent tokens don't run together.
    $rx = [regex]'(?:\*\*(?<brand>.+?)\*\*)|(?:`(?<code>[^`]+?)`)'
    $sb = [System.Text.StringBuilder]::new()
    $pos = 0
    foreach ($m in $rx.Matches($Text)) {
        if ($m.Index -gt $pos) {
            [void]$sb.Append((& $escape $Text.Substring($pos, $m.Index - $pos)))
        }
        if ($m.Groups['brand'].Success) {
            [void]$sb.Append("[$Accent]$(& $escape $m.Groups['brand'].Value)[/]")
        }
        else {
            [void]$sb.Append("[$Code]$(& $escape $m.Groups['code'].Value)[/]")
        }
        $pos = $m.Index + $m.Length
    }
    if ($pos -lt $Text.Length) {
        [void]$sb.Append((& $escape $Text.Substring($pos)))
    }

    $inner = $sb.ToString()
    if ([string]::IsNullOrWhiteSpace($Body) -or $Body -eq 'default') {
        return $inner
    }
    "[$Body]$inner[/]"
}
