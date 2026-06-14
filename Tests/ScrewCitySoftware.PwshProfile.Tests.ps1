#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeDiscovery {
    $manifestPath = Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1'
    $manifestData = Import-PowerShellDataFile -Path $manifestPath
    $exportedFunctions = $manifestData.FunctionsToExport
}

BeforeAll {
    $script:ManifestPath = Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1'
    Import-Module $script:ManifestPath -Force
}

Describe 'ScrewCitySoftware.PwshProfile module' {
    It 'has a valid manifest' {
        { Test-ModuleManifest -Path $script:ManifestPath -ErrorAction Stop } | Should -Not -Throw
    }

    It 'exports exactly the functions listed in the manifest' {
        $manifest = Test-ModuleManifest -Path $script:ManifestPath
        $exported = (Get-Command -Module ScrewCitySoftware.PwshProfile).Name | Sort-Object
        $declared = $manifest.ExportedFunctions.Keys | Sort-Object
        $exported | Should -Be $declared
    }

    It 'has one Public file per exported function, named after it' {
        # Public files are organized into feature subfolders (Install/, Prompt/, Tools/,
        # etc.), so the search recurses; the file name still equals the function name.
        $publicDir = Join-Path $PSScriptRoot '..' 'Public'
        $manifest = Test-ModuleManifest -Path $script:ManifestPath
        $files = (Get-ChildItem -Path $publicDir -Filter *.ps1 -Recurse).BaseName | Sort-Object
        $declared = $manifest.ExportedFunctions.Keys | Sort-Object
        $files | Should -Be $declared
    }
}

Describe 'Comment-based help' {
    It '<_> has a synopsis, description, and at least one example' -ForEach $exportedFunctions {
        $help = Get-Help $_ -Full
        $help.Synopsis | Should -Not -BeNullOrEmpty
        # An auto-generated synopsis (no real help) is just the syntax line starting with the name.
        $help.Synopsis | Should -Not -Match "^\s*$([regex]::Escape($_))"
        $help.Description | Should -Not -BeNullOrEmpty
        @($help.Examples.Example).Count | Should -BeGreaterOrEqual 1
    }
}
