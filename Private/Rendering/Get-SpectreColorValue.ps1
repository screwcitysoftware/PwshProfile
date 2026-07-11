function Get-SpectreColorValue {
    <#
    .SYNOPSIS
        Converts a color string (hex or a Spectre color name) into a [Spectre.Console.Color].

    .DESCRIPTION
        The PwshSpectreConsole prompt cmdlets accept a color as a string because they carry an
        argument-transformation attribute that parses it. Code that talks to the raw Spectre.Console
        API (e.g. Read-PwshProfileFeatureTree, which builds a MultiSelectionPrompt directly) gets no
        such transform, so it needs to convert the string itself. This helper centralizes that:

          - A hex string ('#8fce72', with or without the leading '#') is parsed via
            [Spectre.Console.Color]::TryFromHex.
          - A named Spectre color ('Silver', 'Green', …) is resolved by reflecting the matching
            static property on [Spectre.Console.Color] (case-insensitive).
          - An empty, unrecognized, or unparseable value falls back to [Spectre.Console.Color]::Default.

        [Spectre.Console.Color] is referenced only inside the body (resolved at call time, not at
        module import), so the module still imports when PwshSpectreConsole is unavailable.

    .PARAMETER Color
        The color string to convert — a hex value like '#c9aaff' or a Spectre color name like
        'Silver'. Empty or unrecognized input yields the default color.

    .EXAMPLE
        Get-SpectreColorValue '#8fce72'

        Returns the Spectre.Console.Color for the Forest City green.

    .EXAMPLE
        Get-SpectreColorValue 'Silver'

        Returns the named Spectre 'silver' color.
    #>
    [CmdletBinding()]
    [OutputType([Spectre.Console.Color])]
    param(
        [Parameter(Position = 0)]
        [string]$Color
    )

    $default = [Spectre.Console.Color]::Default
    if ([string]::IsNullOrWhiteSpace($Color)) { return $default }

    $value = $Color.Trim()
    if ($value -match '^#?[0-9a-fA-F]{6}$') {
        $parsed = $default
        if ([Spectre.Console.Color]::TryFromHex($value, [ref]$parsed)) { return $parsed }
        return $default
    }

    $prop = [Spectre.Console.Color].GetProperty($value, [System.Reflection.BindingFlags]'Static,Public,IgnoreCase')
    if ($prop) { return [Spectre.Console.Color]$prop.GetValue($null) }

    return $default
}
