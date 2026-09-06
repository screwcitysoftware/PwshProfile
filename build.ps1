#Requires -Version 7.4
<#
.SYNOPSIS
    Lint, test, stage, and publish the ScrewCitySoftware.PwshProfile module.

.DESCRIPTION
    A self-contained task runner: each value passed to -Task maps to an Invoke-<Task>
    function, and the tasks run in the order given. There is intentionally no build
    framework (psake / Invoke-Build) — the dispatch is a plain switch over a handful of
    functions. The Build task does use ModuleBuilder to compile the module (see build.psd1);
    everything else is stock PowerShell.

    Tasks:
      Bootstrap  Install the dev dependencies pinned in RequiredModules.psd1 (Pester,
                 PSScriptAnalyzer, ModuleBuilder) if missing, and restore the dotnet local
                 tool pinned in .config/dotnet-tools.json (GitVersion.Tool).
      Analyze    Run PSScriptAnalyzer over Public/ and Private/; fail on any finding.
      Test       Run the Pester suite under Tests/ and emit NUnit XML to Output/.
      Build      Stage only the shippable files into Output/<ModuleName>/, stamp the
                 GitVersion-computed SemVer onto the staged manifest, and validate it.
                 CLAUDE.md, Tests/, .github/, build.ps1 never ship.
      Publish    Publish the staged module to the PowerShell Gallery. Requires the
                 PSGALLERY_API_KEY environment variable.
      Version    Print the GitVersion-computed SemVer and exit — a quick standalone check
                 that doesn't require Analyze/Test/Build to run first.

    The default chain (Bootstrap -> Analyze -> Test -> Build) is what CI runs and what
    you should run locally before cutting a release. Publish is intentionally excluded
    from the default so it never fires by accident.

    Versioning: the source manifest's ModuleVersion is a static placeholder ('0.0.1') —
    it is never what ships. GitVersion computes the real SemVer from git tag/commit
    history (see GitVersion.yml) and the Build task stamps it onto the *staged* manifest
    only, via Update-ModuleManifest. The release recipe is: push a vX.Y.Z tag at the
    release commit, cut a GitHub Release from it — since GitVersion resolves an exactly-
    tagged commit's version as that tag, the computed version equals the tag by
    construction, which is what lets publish.yml verify it instead of hand-maintaining it.

.PARAMETER Task
    One or more tasks to run, in order. Defaults to Bootstrap, Analyze, Test, Build.

.EXAMPLE
    ./build.ps1
    Runs the full local chain: Bootstrap -> Analyze -> Test -> Build.

.EXAMPLE
    ./build.ps1 -Task Analyze, Test
    Lints and tests without staging — what the CI workflow runs on pull requests.

.EXAMPLE
    ./build.ps1 -Task Version
    Prints the GitVersion-computed SemVer for the current commit without building anything.

.EXAMPLE
    $env:PSGALLERY_API_KEY = '<key>'; ./build.ps1 -Task Build, Publish
    Stages then publishes to the PowerShell Gallery.

.NOTES
    Used by .github/workflows/ci.yml (Bootstrap/Analyze/Test) and publish.yml
    (Bootstrap/Analyze/Test/Build/Publish on a published GitHub release).
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('Bootstrap', 'Analyze', 'Test', 'Build', 'Publish', 'Version')]
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

# Dev dependencies pinned to EXACT versions so "clean locally" == "clean in CI", read from
# RequiredModules.psd1 rather than hardcoded here. The GitHub windows image preinstalls these,
# and a different analyzer version surfaces different findings; pinning removes that drift
# (Bootstrap force-installs the exact version when it's absent). GitVersion.Tool is pinned
# separately in .config/dotnet-tools.json — it's a dotnet tool, not a PowerShell module.
$DevDependencies = Import-PowerShellDataFile -Path (Join-Path $RepoRoot 'RequiredModules.psd1')

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

    Write-Host '    restoring dotnet local tools (GitVersion.Tool, see .config/dotnet-tools.json)' -ForegroundColor DarkGray
    dotnet tool restore
    if ($LASTEXITCODE -ne 0) {
        throw 'dotnet tool restore failed.'
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

function Get-ComputedVersion {
    <#
        Computes the module's real SemVer from git tag/commit history via GitVersion (pinned in
        .config/dotnet-tools.json, restored by Invoke-Bootstrap), returning the clean
        Major.Minor.Patch (valid for a manifest's ModuleVersion) and a Prerelease tag sanitized
        for PowerShell's manifest charset.

        GitVersion's own PreReleaseTag separates its label/number with a dot (e.g. 'vNext.1'),
        but Update-ModuleManifest's -Prerelease only accepts 'a-zA-Z0-9' plus an optional leading
        hyphen — a dot throws "contains invalid characters" — so non-alphanumerics are stripped
        rather than passed through verbatim.
    #>
    param()

    $json = dotnet tool run dotnet-gitversion $RepoRoot /output json
    if ($LASTEXITCODE -ne 0) {
        throw "GitVersion failed: $json"
    }
    $computed = $json | ConvertFrom-Json

    [pscustomobject]@{
        MajorMinorPatch = $computed.MajorMinorPatch
        Prerelease      = if ($computed.PreReleaseTag) { $computed.PreReleaseTag -replace '[^a-zA-Z0-9]', '' } else { '' }
    }
}

function Invoke-Version {
    $version = Get-ComputedVersion
    $display = if ($version.Prerelease) { "$($version.MajorMinorPatch)-$($version.Prerelease)" } else { $version.MajorMinorPatch }
    Write-Banner "Version: $display"
}

function Invoke-Build {
    Assert-Dependency -Name 'ModuleBuilder' -Version $DevDependencies['ModuleBuilder']
    Import-Module ModuleBuilder -RequiredVersion $DevDependencies['ModuleBuilder']
    Write-Banner "Build: compiling $ModuleName -> $StagePath"

    Remove-OutputRoot

    # ModuleBuilder compiles every Private/ then Public/ function into a single .psm1, which avoids
    # ~9ms of fixed dot-source overhead per file at import — this module is imported on every shell
    # start. See build.psd1 for the settings; notably Prefix.ps1 / Suffix.ps1 are shared verbatim with
    # the dev loader in the source .psm1, so the two cannot drift.
    #
    # Preferred over a hand-rolled merge because it also hoists `using` statements to the top of the
    # compiled file (a naive concatenation breaks the moment a source file gains one), regenerates
    # FunctionsToExport from Public/**/*.ps1, and emits #Region markers naming the source file and
    # line offset — so Convert-LineNumber can map a stack trace in the built module back to the file
    # it came from.
    $built = Invoke-ModuleBuildWithRetry

    # ModuleBuilder copies sibling .psd1 files out of the source folder; the analyzer config is dev
    # tooling and has no business in the gallery package.
    $strays = @('PSScriptAnalyzerSettings.psd1')
    foreach ($stray in $strays) {
        $strayPath = Join-Path $StagePath $stray
        if (Test-Path $strayPath) { Remove-Item -LiteralPath $strayPath -Force }
    }

    # The source manifest's ModuleVersion is a static placeholder ('0.0.1') — GitVersion computes
    # the real SemVer from git tag/commit history and it is stamped onto the staged manifest only,
    # never the source one (which keeps its hand-authored formatting/comments untouched).
    $version = Get-ComputedVersion
    Write-Host "    GitVersion computed $($version.MajorMinorPatch)$(if ($version.Prerelease) { "-$($version.Prerelease)" })" -ForegroundColor DarkGray
    $manifestParams = @{
        Path          = $built.Path
        ModuleVersion = $version.MajorMinorPatch
        ErrorAction   = 'Stop'
    }
    if ($version.Prerelease) { $manifestParams.Prerelease = $version.Prerelease }
    Update-ModuleManifest @manifestParams

    # The staged manifest must be valid before we ever try to publish it.
    $null = Test-ModuleManifest -Path $built.Path -ErrorAction Stop

    # The compiled module is a different artifact from the source tree the tests import, so prove it
    # actually loads and exports what the manifest promises before it can be published.
    Assert-StagedModule -Manifest $built.Path

    $count = (Get-ChildItem -Path $StagePath -Recurse -File).Count
    Write-Host "    staged $count file(s)" -ForegroundColor Green
}


function Invoke-ModuleBuildWithRetry {
    <#
        Runs Build-Module, retrying from a clean output directory on a transient file lock.

        ModuleBuilder writes the compiled .psm1 and then re-reads it in the same pass, and on Windows
        that can collide with whatever still has the freshly written file open — the indexer, AV, or
        ModuleBuilder's own handle. It surfaces as "The process cannot access the file ... because it
        is being used by another process."

        It is load-sensitive rather than deterministic: back-to-back builds run clean on an idle
        machine, and failed roughly a quarter of the time while a dozen other pwsh processes were
        alive. That makes it exactly the kind of thing to retry rather than diagnose per-run, and it
        is not specific to a ModuleBuilder version (3.1.8 and 3.2.18 both build clean when idle).
    #>
    param()

    foreach ($attempt in 1..4) {
        try {
            return Build-Module -SourcePath (Join-Path $RepoRoot 'build.psd1') -Passthru -ErrorAction Stop
        }
        catch {
            if ($attempt -eq 4) { throw }
            Write-Host "    build attempt $attempt hit a file lock; retrying" -ForegroundColor DarkYellow
            # The stale handle is usually ModuleBuilder's own FileStream awaiting finalization, and the
            # retry runs in this same process — so without forcing finalizers the next attempt hits
            # exactly the same lock.
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            Start-Sleep -Milliseconds (250 * $attempt)
            Remove-OutputRoot
        }
    }
}
function Remove-OutputRoot {
    <#
        Deletes the staging directory, retrying briefly on failure.

        Windows can hold a handle on a just-written file for a moment after the writing process is
        done with it (the indexer and AV both do this), which surfaces as "The directory is not empty"
        on an immediate recursive delete. Measured at roughly one failure in six on back-to-back
        builds, so a couple of short retries turns a flaky build into a reliable one.
    #>
    param()

    if (-not (Test-Path $OutputRoot)) { return }

    foreach ($attempt in 1..5) {
        try {
            Remove-Item -Path $OutputRoot -Recurse -Force -ErrorAction Stop
            return
        }
        catch {
            if ($attempt -eq 5) { throw }
            Start-Sleep -Milliseconds (100 * $attempt)
        }
    }
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
