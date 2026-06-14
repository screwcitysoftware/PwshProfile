function Get-StepIconPrefix {
    <#
    .SYNOPSIS
        Returns a step icon normalized as a render-ready prefix: the icon plus one separating space.

    .DESCRIPTION
        The step marker icon is stored as a bare value (e.g. ':nut_and_bolt:'), and the single space
        that separates the glyph from the step text is added where the icon is rendered — not carried
        on the value. This helper is that one place: it trims any trailing whitespace off the icon and
        appends exactly one space, so callers can simply prefix it to the step text.

        Trimming first makes it idempotent: a legacy value that still carries a trailing space (e.g. an
        older ':nut_and_bolt: ' baked into a user's $PROFILE) renders with one space, not two. An empty
        or whitespace-only icon yields an empty string, so no stray leading space appears.

    .PARAMETER Icon
        The icon value (a Spectre emoji shortcode like ':nut_and_bolt:' or a literal glyph). May be
        empty.

    .EXAMPLE
        Get-StepIconPrefix ':gear:'

        Returns ':gear: ' (one trailing space).

    .EXAMPLE
        "$(Get-StepIconPrefix $Icon)$Description"

        The canonical use: prefix the icon to the step text. With an empty icon this is just the text.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0)]
        [string]$Icon
    )

    $trimmed = ([string]$Icon).TrimEnd()
    if ($trimmed) { "$trimmed " } else { '' }
}
