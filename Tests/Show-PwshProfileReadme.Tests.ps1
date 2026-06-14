#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Readme = Join-Path $PSScriptRoot '..' 'README.md'
}

Describe 'Show-PwshProfileReadme' {
    BeforeEach {
        # Stub the side-effecting cmdlets in module scope so the test neither renders to the
        # console nor launches an external app.
        Mock -ModuleName ScrewCitySoftware.PwshProfile Show-Markdown { }
        Mock -ModuleName ScrewCitySoftware.PwshProfile Invoke-Item { }
    }

    It 'renders with Show-Markdown by default and does not open an app' {
        Show-PwshProfileReadme
        Should -Invoke -ModuleName ScrewCitySoftware.PwshProfile Show-Markdown -Times 1 -Exactly
        Should -Invoke -ModuleName ScrewCitySoftware.PwshProfile Invoke-Item -Times 0 -Exactly
    }

    It 'opens the default app with -Open and does not render in the console' {
        Show-PwshProfileReadme -Open
        Should -Invoke -ModuleName ScrewCitySoftware.PwshProfile Invoke-Item -Times 1 -Exactly
        Should -Invoke -ModuleName ScrewCitySoftware.PwshProfile Show-Markdown -Times 0 -Exactly
    }

    It 'passes the module README path to Show-Markdown' {
        $expected = (Resolve-Path -Path $script:Readme).Path
        Show-PwshProfileReadme
        Should -Invoke -ModuleName ScrewCitySoftware.PwshProfile Show-Markdown -Times 1 -Exactly `
            -ParameterFilter { $Path -eq $expected }
    }
}
