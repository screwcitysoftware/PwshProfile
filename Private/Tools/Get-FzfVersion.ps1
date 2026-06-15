function Get-FzfVersion {
    <#
    .SYNOPSIS
        Returns the installed fzf version as a [version], or $null when it can't be determined.

    .DESCRIPTION
        Runs `fzf --version` and parses the leading `MAJOR.MINOR` (fzf prints e.g.
        "0.65.0 (devel)" or "0.54.3 (brew)") into a [version]. Used by Enable-Fzf to gate the
        `--style` option, which is an fzf 0.54+ feature: because Install-WingetPackageSafe
        short-circuits when fzf.exe is already on PATH, a pre-existing older fzf is never upgraded,
        and feeding it `--style` would break every fzf invocation (and zoxide's `cdi`).

        Failure-tolerant by design (it gates a cosmetic option during startup, so it must never
        throw): a missing exe, a non-zero exit, or unparseable output all return $null, and the
        caller treats $null as "don't risk --style". It shells out once per Enable-Fzf call (i.e.
        once per session), the same one-shot cost the other tool enablers pay at init.

    .EXAMPLE
        if ((Get-FzfVersion) -ge [version]'0.54') { $opts.Add("--style=$Style") }

        Adds fzf's --style only when the installed fzf is new enough to understand it.

    .NOTES
        Only MAJOR.MINOR is parsed — patch/suffix segments are irrelevant to feature gating and
        fzf's pre-release suffixes ("(devel)") don't fit [version]'s numeric form.
    #>
    [CmdletBinding()]
    [OutputType([version])]
    param()

    try {
        if (-not (Get-Command fzf.exe -ErrorAction SilentlyContinue)) { return $null }
        $out = (fzf --version 2>$null) | Out-String
        if ($out -match '(\d+)\.(\d+)') {
            return [version]("{0}.{1}" -f $Matches[1], $Matches[2])
        }
        return $null
    }
    catch {
        return $null
    }
}
