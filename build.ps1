#Requires -Version 7.4
<#
.SYNOPSIS
    Lint, test, stage, and publish the ScrewCitySoftware.PwshProfile module.

.DESCRIPTION
    A dependency-free task runner: each value passed to -Task maps to an Invoke-<Task>
    function, and the tasks run in the order given. There is intentionally no build
    framework (psake / Invoke-Build) — the module's ethos is dependency-light, so the
    dispatch is a plain switch over a handful of functions.

    Tasks:
      Bootstrap  Install the dev dependencies (Pester, PSScriptAnalyzer) if missing.
      Analyze    Run PSScriptAnalyzer over Public/ and Private/; fail on any finding.
      Test       Run the Pester suite under Tests/ and emit NUnit XML to Output/.
      Build      Stage only the shippable files into Output/<ModuleName>/ and validate
                 the staged manifest. CLAUDE.md, Tests/, .github/, build.ps1 never ship.
      Publish    Publish the staged module to the PowerShell Gallery. Requires the
                 PSGALLERY_API_KEY environment variable.

    The default chain (Bootstrap -> Analyze -> Test -> Build) is what CI runs and what
    you should run locally before cutting a release. Publish is intentionally excluded
    from the default so it never fires by accident.

.PARAMETER Task
    One or more tasks to run, in order. Defaults to Bootstrap, Analyze, Test, Build.

.EXAMPLE
    ./build.ps1
    Runs the full local chain: Bootstrap -> Analyze -> Test -> Build.

.EXAMPLE
    ./build.ps1 -Task Analyze, Test
    Lints and tests without staging — what the CI workflow runs on pull requests.

.EXAMPLE
    $env:PSGALLERY_API_KEY = '<key>'; ./build.ps1 -Task Build, Publish
    Stages then publishes to the PowerShell Gallery.

.NOTES
    Used by .github/workflows/ci.yml (Bootstrap/Analyze/Test) and publish.yml
    (Analyze/Test/Build/Publish on a published GitHub release).
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('Bootstrap', 'Analyze', 'Test', 'Build', 'Publish')]
    [string[]]$Task = @('Bootstrap', 'Analyze', 'Test', 'Build')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ModuleName       = 'ScrewCitySoftware.PwshProfile'
$RepoRoot         = $PSScriptRoot
$ManifestPath     = Join-Path $RepoRoot "$ModuleName.psd1"
$OutputRoot       = Join-Path $RepoRoot 'Output'
$StagePath        = Join-Path $OutputRoot $ModuleName
$TestsPath        = Join-Path $RepoRoot 'Tests'
$AnalyzerSettings = Join-Path $RepoRoot 'PSScriptAnalyzerSettings.psd1'

# Dev dependencies pinned to EXACT versions so "clean locally" == "clean in CI". The GitHub
# windows image preinstalls these, and a different analyzer version surfaces different findings;
# pinning removes that drift (Bootstrap force-installs the exact version when it's absent).
$DevDependencies = @{
    Pester           = '5.7.1'
    PSScriptAnalyzer = '1.25.0'
}

function Write-Banner {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Assert-Dependency {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Version
    )
    $found = Get-Module -ListAvailable -Name $Name |
        Where-Object { $_.Version -eq [version]$Version }
    if (-not $found) {
        throw "$Name $Version not found. Run: ./build.ps1 -Task Bootstrap"
    }
}

function Invoke-Bootstrap {
    Write-Banner "Bootstrap: ensuring $($DevDependencies.Keys -join ', ')"
    foreach ($name in $DevDependencies.Keys) {
        $version = $DevDependencies[$name]
        $have = Get-Module -ListAvailable -Name $name |
            Where-Object { $_.Version -eq [version]$version }
        if ($have) {
            Write-Host "    $name $version already present" -ForegroundColor DarkGray
        }
        else {
            Write-Host "    installing $name $version" -ForegroundColor DarkGray
            # Bracket = NuGet exact-version range, so we get this version and no other.
            Install-PSResource -Name $name -Version "[$version]" -TrustRepository
        }
    }
}

function Invoke-Analyze {
    Assert-Dependency -Name 'PSScriptAnalyzer' -Version $DevDependencies['PSScriptAnalyzer']
    Import-Module PSScriptAnalyzer -RequiredVersion $DevDependencies['PSScriptAnalyzer']
    Write-Banner 'Analyze: PSScriptAnalyzer over Public/ and Private/'

    $targets = 'Public', 'Private' | ForEach-Object { Join-Path $RepoRoot $_ }
    # @() so a single finding is still an array — $results.Count is unsafe on a scalar
    # DiagnosticRecord under Set-StrictMode -Version Latest.
    $results = @(foreach ($target in $targets) {
            Invoke-ScriptAnalyzer -Path $target -Recurse -Settings $AnalyzerSettings
        })

    if ($results.Count -gt 0) {
        $results | Format-Table -AutoSize | Out-String | Write-Host
        throw "PSScriptAnalyzer found $($results.Count) issue(s)."
    }
    Write-Host '    clean' -ForegroundColor Green
}

function Invoke-Test {
    Assert-Dependency -Name 'Pester' -Version $DevDependencies['Pester']
    Import-Module Pester -RequiredVersion $DevDependencies['Pester']
    Write-Banner 'Test: Pester suite under Tests/'

    if (-not (Test-Path $OutputRoot)) {
        New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
    }

    $config = New-PesterConfiguration
    $config.Run.Path = $TestsPath
    $config.Run.Throw = $false
    $config.Run.PassThru = $true   # so Invoke-Pester returns the result object below
    $config.Output.Verbosity = 'Detailed'
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputFormat = 'NUnitXml'
    $config.TestResult.OutputPath = (Join-Path $OutputRoot 'testResults.xml')

    $result = Invoke-Pester -Configuration $config
    if ($result.FailedCount -gt 0) {
        throw "$($result.FailedCount) test(s) failed."
    }
    Write-Host "    $($result.PassedCount) test(s) passed" -ForegroundColor Green
}

function Invoke-Build {
    Write-Banner "Build: staging $ModuleName -> $StagePath"

    if (Test-Path $OutputRoot) {
        Remove-Item -Path $OutputRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Path $StagePath -Force | Out-Null

    # Only the shippable set — Tests/, CLAUDE.md, .github/, build.ps1, etc. never ship. Public/ and
    # Private/ are absent on purpose: their contents are merged into the staged .psm1 below, so the
    # package carries one copy of every function rather than two.
    $shippable = @(
        "$ModuleName.psd1"
        'Assets'
        'README.md'
        'LICENSE'
    )
    foreach ($item in $shippable) {
        $src = Join-Path $RepoRoot $item
        if (-not (Test-Path $src)) {
            throw "Expected to stage '$item' but it was not found at $src"
        }
        Copy-Item -Path $src -Destination $StagePath -Recurse -Force
    }

    Build-MergedRootModule -Destination (Join-Path $StagePath "$ModuleName.psm1")

    # The staged manifest must be valid before we ever try to publish it.
    $stagedManifest = Join-Path $StagePath "$ModuleName.psd1"
    $null = Test-ModuleManifest -Path $stagedManifest -ErrorAction Stop

    # The staged module is a different artifact from the source tree the tests import, so prove it
    # actually loads and exports what the manifest promises before it can be published.
    Assert-StagedModule -Manifest $stagedManifest

    $count = (Get-ChildItem -Path $StagePath -Recurse -File).Count
    Write-Host "    staged $count file(s)" -ForegroundColor Green
}

function Build-MergedRootModule {
    <#
        Concatenates every Public/ and Private/ function file into a single root module.

        The repo keeps one function per file, which is right for editing but costs ~9 ms of fixed
        dot-source overhead per file at import — roughly 650 ms across the tree, and this module is
        imported on every shell start. Merging collapses that to a single parse (~26 ms measured).

        Load order matches the dev loader exactly (Private first, then Public, each recursed) so a
        helper is always defined before the function that calls it. Bundled-asset paths hang off
        $script:ModuleRoot rather than a per-file $PSScriptRoot precisely so they survive this merge.
    #>
    param([Parameter(Mandatory)][string]$Destination)

    $sourcePsm1 = Join-Path $RepoRoot "$ModuleName.psm1"
    $lines = [System.IO.File]::ReadAllLines($sourcePsm1)

    # Reuse the dev loader's own preamble (console encoding + $script:ModuleRoot) so the two can't
    # drift; everything from the loader comment onward is replaced by the merged bodies.
    $loaderStart = [Array]::FindIndex([string[]]$lines, [Predicate[string]] { $args[0] -like '# Loader:*' })
    if ($loaderStart -lt 0) {
        throw "Could not find the '# Loader:' marker in $sourcePsm1; the merge cannot determine where the preamble ends."
    }

    $merged = [System.Collections.Generic.List[string]]::new()
    $merged.AddRange([string[]]$lines[0..($loaderStart - 1)])
    $merged.Add('# Generated by build.ps1 -Task Build: every Public/ and Private/ function file, merged')
    $merged.Add('# in the dev loader''s order. Edit the sources in the repo, never this file.')
    $merged.Add('')

    $private = @(Get-ChildItem -Path (Join-Path $RepoRoot 'Private') -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue)
    $public = @(Get-ChildItem -Path (Join-Path $RepoRoot 'Public') -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue)
    if ($public.Count -eq 0) {
        throw "No Public/*.ps1 files found under $RepoRoot; refusing to stage a module with no functions."
    }

    foreach ($file in $private + $public) {
        $merged.Add("#region $($file.BaseName)")
        $merged.AddRange([string[]][System.IO.File]::ReadAllLines($file.FullName))
        $merged.Add('#endregion')
        $merged.Add('')
    }

    # Same tail as the dev loader: ensure the renderer, then export the public base names.
    $merged.Add('Import-ModuleSafe PwshSpectreConsole')
    $merged.Add('')
    $exported = ($public.BaseName | Sort-Object | ForEach-Object { "'$_'" }) -join ', '
    $merged.Add("Export-ModuleMember -Function @($exported)")

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Destination, ($merged -join "`r`n") + "`r`n", $utf8NoBom)
    Write-Host "    merged $($private.Count + $public.Count) file(s) into $(Split-Path $Destination -Leaf)" -ForegroundColor Green
}

function Assert-StagedModule {
    <#
        Imports the staged module in a clean child process and checks it exports exactly what the
        manifest declares. The Pester suite runs against the repo tree, so without this the merged
        artifact would never be loaded before publish.
    #>
    param([Parameter(Mandatory)][string]$Manifest)

    $expected = @((Import-PowerShellDataFile -Path $Manifest).FunctionsToExport) | Sort-Object
    $actual = @(pwsh -NoProfile -NoLogo -Command "
        Import-Module '$Manifest' -Force -ErrorAction Stop
        (Get-Command -Module '$ModuleName').Name | Sort-Object
    ")
    if ($LASTEXITCODE -ne 0) {
        throw "The staged module at $Manifest failed to import."
    }

    $missing = @($expected | Where-Object { $_ -notin $actual })
    $extra = @($actual | Where-Object { $_ -notin $expected })
    if ($missing -or $extra) {
        throw ("Staged module exports do not match the manifest." +
            $(if ($missing) { " Missing: $($missing -join ', ')." }) +
            $(if ($extra) { " Unexpected: $($extra -join ', ')." }))
    }
    Write-Host "    staged module imports and exports all $($expected.Count) function(s)" -ForegroundColor Green
}

function Invoke-Publish {
    if (-not (Test-Path $StagePath)) {
        throw "Nothing staged at $StagePath. Run: ./build.ps1 -Task Build"
    }
    if ([string]::IsNullOrWhiteSpace($env:PSGALLERY_API_KEY)) {
        throw 'PSGALLERY_API_KEY is not set; cannot publish.'
    }
    Write-Banner "Publish: $ModuleName -> PowerShell Gallery"
    Publish-PSResource -Path $StagePath -ApiKey $env:PSGALLERY_API_KEY -Repository PSGallery
    Write-Host '    published' -ForegroundColor Green
}

foreach ($t in $Task) {
    & "Invoke-$t"
}
