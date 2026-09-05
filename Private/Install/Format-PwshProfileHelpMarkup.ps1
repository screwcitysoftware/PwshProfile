function Format-PwshProfileHelpMarkup {
    <#
    .SYNOPSIS
        Converts a light, markdown-ish help string into safe Spectre markup with two-color highlighting
        for the Install-PwshProfile wizard.

    .DESCRIPTION
        The single source of truth for how the install wizard highlights its text. Authors write help
        strings in a small convention and this emits the markup the prompt helpers render:

          **term**      ->  the accent color, for tool and product names
          `code`        ->  the code color, for file types, commands and paths
          anything else ->  escaped and left in the body color

        Everything outside the two token kinds — and the token contents themselves — is escaped via
        Get-SpectreEscapedText, so authored text containing brackets is safe, and the whole line is
        wrapped in the body style. Spectre resolves nested styles with a stack, so a span inside the
        body wrapper correctly reverts when it closes. Without Get-SpectreEscapedText it falls back to
        doubling brackets by hand, per the module's degrade-don't-throw rule.

    .PARAMETER Text
        The help string to format. May be empty.

    .PARAMETER Accent
        The color for **...** spans. Defaults to the module's signature purple (#c9aaff).

    .PARAMETER Code
        The color for `...` spans. Defaults to a soft cyan (#5fd7ff).

    .PARAMETER Body
        The style wrapping plain body text, default 'grey'. Pass 'default' or an empty string to leave
        the body in the terminal's own color, for when the surrounding context already sets one.

    .EXAMPLE
        Format-PwshProfileHelpMarkup -Text 'Use **zoxide** by typing `cd` to jump.'

        Returns '[grey]Use [#c9aaff]zoxide[/] by typing [#5fd7ff]cd[/] to jump.[/]'.

    .EXAMPLE
        Format-PwshProfileHelpMarkup -Text 'custom: **forestcity**' -Body default

        Same highlighting with no grey wrapper, so the value sits in the surrounding color.
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

    # Match **brand** or `code`, non-greedily, so adjacent tokens don't run together.
    $rx = [regex]'(?:\*\*(?<brand>.+?)\*\*)|(?:`(?<code>[^`]+?)`)'
    $sb = [System.Text.StringBuilder]::new()
    $pos = 0
    foreach ($m in $rx.Matches($Text)) {
        if ($m.Index -gt $pos) {
            [void]$sb.Append((Get-SpectreEscapedTextSafe -Text $Text.Substring($pos, $m.Index - $pos)))
        }
        if ($m.Groups['brand'].Success) {
            [void]$sb.Append("[$Accent]$(Get-SpectreEscapedTextSafe -Text $m.Groups['brand'].Value)[/]")
        }
        else {
            [void]$sb.Append("[$Code]$(Get-SpectreEscapedTextSafe -Text $m.Groups['code'].Value)[/]")
        }
        $pos = $m.Index + $m.Length
    }
    if ($pos -lt $Text.Length) {
        [void]$sb.Append((Get-SpectreEscapedTextSafe -Text $Text.Substring($pos)))
    }

    $inner = $sb.ToString()
    if ([string]::IsNullOrWhiteSpace($Body) -or $Body -eq 'default') {
        return $inner
    }
    "[$Body]$inner[/]"
}
