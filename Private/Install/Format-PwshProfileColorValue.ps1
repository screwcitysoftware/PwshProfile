function Format-PwshProfileColorValue {
    <#
    .SYNOPSIS
        Renders a color value (hex or a Spectre color name) as a small colored swatch followed by the
        value text, for the Install-PwshProfile wizard.

    .DESCRIPTION
        The install wizard shows the chosen banner color in a few places (the prompt echo, the Banner
        step's current-config table, and the review panel). Shown as bare text, a value like '#c9aaff'
        tells the user nothing about what it looks like. This helper turns the value into Spectre markup
        that draws a filled swatch block in that color, then the value text left in the surrounding
        (readable) color — so even very dark colors stay legible:

          #c9aaff  ->  [#c9aaff]███[/] #c9aaff   (the block tinted, the label plain)

        The color is validated and normalized through Get-SpectreColorValue: a hex string (with or
        without the leading '#') or a named Spectre color resolves to a [Spectre.Console.Color], whose
        ToHex() gives the markup tag — so 'c9aaff' (no '#') and named colors like 'Aqua' all produce a
        valid '[#rrggbb]' tag. An empty, unrecognized, or unparseable value (Get-SpectreColorValue
        returns [Spectre.Console.Color]::Default) yields just the escaped value with no swatch, preserving
        the previous plain-text behavior for junk input.

        [Spectre.Console.Color] is unavailable when PwshSpectreConsole isn't loaded, so the resolution is
        wrapped in try/catch — on failure it returns the escaped value, matching the module's
        degrade-don't-throw rule. The value text is always escaped via Get-SpectreEscapedTextSafe so it
        can never inject markup.

    .PARAMETER Color
        The color value to render — a hex string like '#c9aaff' (or 'c9aaff') or a Spectre color name
        like 'Aqua'. Empty or unrecognized input renders as plain escaped text with no swatch.

    .EXAMPLE
        Format-PwshProfileColorValue '#c9aaff'

        Returns '[#c9aaff]███[/] #c9aaff' — a purple swatch followed by the value.

    .EXAMPLE
        Format-PwshProfileColorValue 'not-a-color'

        Returns 'not-a-color' (escaped, no swatch) because the value doesn't resolve to a color.

    .NOTES
        Private helper for the install-wizard chrome (Invoke-PwshProfileWizard,
        Read-PwshProfileSettingChange). Reuses Get-SpectreColorValue for parsing/validation and
        Get-SpectreEscapedTextSafe for escaping.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0)]
        [string]$Color = ''
    )

    # An empty value has no swatch and nothing to escape (Get-SpectreEscapedText rejects empty input).
    if ([string]::IsNullOrEmpty("$Color")) { return '' }

    $escaped = Get-SpectreEscapedTextSafe -Text "$Color"

    # Resolve + validate the color. The Spectre type is absent when PwshSpectreConsole isn't loaded, so
    # degrade to the plain escaped value rather than throwing.
    try {
        $parsed = Get-SpectreColorValue -Color $Color
        if ($parsed -eq [Spectre.Console.Color]::Default) { return $escaped }
        $hex = $parsed.ToHex()
    }
    catch {
        return $escaped
    }

    "[#$hex]███[/] $escaped"
}
