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

    # Only the shippable set — Tests/, CLAUDE.md, .github/, build.ps1, etc. never ship.
    $shippable = @(
        "$ModuleName.psd1"
        "$ModuleName.psm1"
        'Public'
        'Private'
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

    # The staged manifest must be valid before we ever try to publish it.
    $stagedManifest = Join-Path $StagePath "$ModuleName.psd1"
    $null = Test-ModuleManifest -Path $stagedManifest -ErrorAction Stop

    $count = (Get-ChildItem -Path $StagePath -Recurse -File).Count
    Write-Host "    staged $count file(s)" -ForegroundColor Green
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
