#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Readme = Join-Path $PSScriptRoot '..' 'README.md'
}

Describe 'Show-PwshProfileReadme' {
    BeforeEach {
        # Stub the side-effecting cmdlets in module scope so the test neither renders to the
        # console, mutates the session's real markdown options, nor launches an external app.
        Mock -ModuleName ScrewCitySoftware.PwshProfile Show-Markdown { }
        Mock -ModuleName ScrewCitySoftware.PwshProfile Invoke-Item { }
        Mock -ModuleName ScrewCitySoftware.PwshProfile Set-MarkdownOption { }
        Mock -ModuleName ScrewCitySoftware.PwshProfile Get-MarkdownOption { [pscustomobject]@{ PriorOption = $true } }
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

    It 'applies the screwcity theme''s header/code colors by default' {
        Show-PwshProfileReadme
        Should -Invoke -ModuleName ScrewCitySoftware.PwshProfile Set-MarkdownOption -Times 1 -Exactly `
            -ParameterFilter { $Header1Color -eq '[1;38;2;201;170;255m' -and $Code -eq '[38;2;95;215;255m' }
    }

    It 'applies the forestcity theme''s header/code colors when -Theme forestcity is passed' {
        Show-PwshProfileReadme -Theme forestcity
        Should -Invoke -ModuleName ScrewCitySoftware.PwshProfile Set-MarkdownOption -Times 1 -Exactly `
            -ParameterFilter { $Header1Color -eq '[1;38;2;143;206;114m' -and $Code -eq '[38;2;102;217;197m' }
    }

    It 'restores the prior markdown options afterward' {
        Show-PwshProfileReadme
        Should -Invoke -ModuleName ScrewCitySoftware.PwshProfile Set-MarkdownOption -Times 1 -Exactly `
            -ParameterFilter { $InputObject -and $InputObject.PriorOption -eq $true }
    }

    It 'never touches markdown options with -Open' {
        Show-PwshProfileReadme -Open
        Should -Invoke -ModuleName ScrewCitySoftware.PwshProfile Get-MarkdownOption -Times 0 -Exactly
        Should -Invoke -ModuleName ScrewCitySoftware.PwshProfile Set-MarkdownOption -Times 0 -Exactly
    }
}
