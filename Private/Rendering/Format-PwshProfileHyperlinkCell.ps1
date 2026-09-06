function Format-PwshProfileHyperlinkCell {
    <#
    .SYNOPSIS
        Wraps text in a Spectre hyperlink span, padded to a column width.

    .DESCRIPTION
        Shared by Show-PwshProfileChord and Show-PwshProfileInventory for their linked columns (a
        chord name, a tool label). Padding is applied with plain spaces AFTER the closing `[/]` tag,
        keyed to the unescaped text's length, rather than by padding the text itself before wrapping it
        in the span — padding inside "[link=...]...[/]" would render as part of the clickable link in
        a real terminal. Never escape the assembled markup string as a whole: escaping doubles
        brackets and would corrupt the link syntax rather than the (already-safe) text inside it.

    .PARAMETER Text
        The unescaped display text.

    .PARAMETER Url
        The link target.

    .PARAMETER Width
        The column width to pad Text to.

    .PARAMETER Escape
        Escape Text with Get-SpectreEscapedTextSafe before wrapping it in the link span, for text that
        isn't already known to be markup-safe (e.g. a catalog label). Omit for text from a fixed,
        already-safe set (e.g. a chord name).

    .EXAMPLE
        Format-PwshProfileHyperlinkCell -Text 'Ctrl+t' -Url 'https://...' -Width 10

    .EXAMPLE
        Format-PwshProfileHyperlinkCell -Text $rawLabel -Url $url -Width $width -Escape
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter(Mandatory)]
        [int]$Width,

        [Parameter()]
        [switch]$Escape
    )

    $displayText = if ($Escape) { Get-SpectreEscapedTextSafe -Text $Text } else { $Text }
    "[link=$Url]$displayText[/]" + (' ' * ($Width - $Text.Length))
}
