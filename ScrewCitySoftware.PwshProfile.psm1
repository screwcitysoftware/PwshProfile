# Dev loader: what an in-repo `Import-Module ./ScrewCitySoftware.PwshProfile.psd1` uses.
#
# The SHIPPED module is compiled by ModuleBuilder (build.ps1 -Task Build) into a single .psm1 with
# every function inlined, which avoids ~9ms of fixed dot-source overhead per file at import. Prefix.ps1
# and Suffix.ps1 are shared verbatim between this loader and that build (ModuleBuilder's -Prefix /
# -Suffix), so the console-encoding preamble and the renderer check cannot drift between the two.
. $PSScriptRoot/Prefix.ps1

# Public/  — exported functions, one per file, file named after the function.
# Private/ — internal helpers (not exported); the folder is optional and may not exist.
# Both trees are organized into feature subfolders (Install/, Prompt/, Tools/, etc.), so the search
# recurses; folder nesting is purely organizational and never affects which functions are exported
# (the manifest's FunctionsToExport stays a flat list, and ModuleBuilder regenerates it from
# Public/**/*.ps1 at build time).
$public = @(Get-ChildItem -Path $PSScriptRoot/Public -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue)
$private = @(Get-ChildItem -Path $PSScriptRoot/Private -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue)

foreach ($file in $private + $public) {
    . $file.FullName
}

. $PSScriptRoot/Suffix.ps1

# File name == function name is the repo convention, so BaseName is the export list.
Export-ModuleMember -Function $public.BaseName
