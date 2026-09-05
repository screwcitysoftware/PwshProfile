@{
    # ModuleBuilder configuration, consumed by Build-Module from build.ps1 -Task Build.
    # (build.ps1 is the task runner; this file only describes how the module is compiled.)

    # The source manifest. ModuleBuilder sweeps SourceDirectories beneath it, recursing into the
    # feature subfolders, and regenerates FunctionsToExport from PublicFilter.
    SourcePath                 = './ScrewCitySoftware.PwshProfile.psd1'

    OutputDirectory            = './Output'

    # Stage to Output/<ModuleName>/ rather than Output/<ModuleName>/<Version>/, matching what the
    # Publish task and the README's layout expect.
    UnversionedOutputDirectory = $true

    # Private first so a helper is always defined before the function that calls it. This module has
    # no Enum/ or Classes/ folders, so they are omitted rather than listed and ignored.
    SourceDirectories          = @('Private', 'Public')

    # Public/**/*.ps1 rather than ModuleBuilder's default Public/*.ps1: the exported functions live in
    # feature subfolders (Public/Tools/, Public/Rendering/, ...), and the default filter would match
    # none of them and export nothing.
    PublicFilter               = 'Public/**/*.ps1'

    # Shared verbatim with the dev loader in the .psm1, so the console-encoding preamble and the
    # renderer check cannot drift between an in-repo import and the shipped module.
    Prefix                     = 'Prefix.ps1'
    Suffix                     = 'Suffix.ps1'

    # Everything the module reads at runtime. Assets/ carries the bundled themes and FIGlet fonts;
    # README.md is what Show-PwshProfileReadme opens.
    CopyPaths                  = @('./Assets', './README.md', './LICENSE')

    # No script generators. The two built-ins (Add-Parameter, Merge-ScriptBlock) inject boilerplate
    # into functions, which this module does not use — and ModuleBuilder runs the generator pipeline
    # even when none are configured — re-parsing and rewriting the freshly written .psm1, which is a
    # pointless pass over ~6,500 lines and one more chance to hit the file-handle race Invoke-Build
    # retries around. Hoisting of `using` statements is a separate step and still runs, verified
    # against a source file temporarily given one.
    Generators                 = @{}

    # The repo is deliberately UTF-8 without a BOM (see PSScriptAnalyzerSettings.psd1, which suppresses
    # PSUseBOMForUnicodeEncodedFile for that reason); ModuleBuilder defaults to writing one.
    Encoding                   = 'UTF8NoBom'
}
