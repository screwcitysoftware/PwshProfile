# UTF-8 before anything else loads: PwshSpectreConsole renders through [Console]::Out, so at the
# default OEM code page every non-ASCII glyph (step icons, nerd-font segments, figlet banners) is
# mangled by the encoder. ::new() is the BOM-less ctor — [Text.Encoding]::UTF8 would prepend
# EF BB BF to everything piped into git/jq/fzf. The [Console] properties are console-wide
# (SetConsoleCP), not process-local. Guarded because import must never throw.
try {
    $utf8NoBom = [System.Text.UTF8Encoding]::new()
    [console]::InputEncoding  = $utf8NoBom
    [console]::OutputEncoding = $utf8NoBom
    $global:OutputEncoding    = $utf8NoBom
}
catch {
    Write-Warning "ScrewCitySoftware.PwshProfile: could not set UTF-8 console encoding ($($_.Exception.Message)). Non-ASCII glyphs may render incorrectly."
}

# The module root, resolved once. Every bundled-asset path (Assets/, README.md) hangs off this
# rather than a per-file $PSScriptRoot, so the same code works whether the module is dot-sourced
# file-by-file in the repo or compiled into a single .psm1 by ModuleBuilder (build.ps1 -Task Build).
$script:ModuleRoot = $PSScriptRoot

