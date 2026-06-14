[console]::InputEncoding  = [System.Text.UTF8Encoding]::new()
[console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$global:OutputEncoding    = [System.Text.UTF8Encoding]::new()

# Loader: dot-source every function file and export the public ones.
# Public/  — exported functions, one per file, file named after the function.
# Private/ — internal helpers (not exported); the folder is optional and may not exist.
# Both trees are organized into feature subfolders (Install/, Prompt/, Tools/, etc.),
# so the search recurses; folder nesting is purely organizational and never affects
# which functions are exported (the manifest's FunctionsToExport stays a flat list).
$public = @(Get-ChildItem -Path $PSScriptRoot/Public -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue)
$private = @(Get-ChildItem -Path $PSScriptRoot/Private -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue)

foreach ($file in $private + $public) {
    . $file.FullName
}

# The module renders through PwshSpectreConsole (Invoke-Step, Write-Figlet); ensure it's
# present. The startup banner is now rendered on demand via Write-Figlet, not at import,
# so no initialization block is needed here.
Import-ModuleSafe PwshSpectreConsole

# File name == function name is the repo convention, so BaseName is the export list.
Export-ModuleMember -Function $public.BaseName
