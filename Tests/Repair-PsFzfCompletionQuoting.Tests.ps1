#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
}

Describe 'Repair-PsFzfCompletionQuoting' {
    It 'is a safe no-op when PSFzf is not loaded' {
        Mock -ModuleName $script:Module Get-Module { $null }
        { & (Get-Module $script:Module) { Repair-PsFzfCompletionQuoting } } | Should -Not -Throw
    }

    Context 'with a stand-in PSFzf module loaded' {
        BeforeEach {
            # A single dynamic stand-in named PSFzf carrying the original (un-trimmed) helper:
            # quotes anything containing whitespace, including a trailing "complete" space — the
            # behavior the patch corrects. Defined literally here (not via a passed-in scriptblock)
            # so the function lands in the dynamic module's own scope.
            Remove-Module PSFzf -Force -ErrorAction SilentlyContinue
            New-Module -Name PSFzf {
                function FixCompletionResult($str, [switch]$AlwaysQuote) {
                    if ([string]::IsNullOrEmpty($str)) { return '' }
                    $str = $str.Replace("`r`n", '')
                    $isAlreadyQuoted = ($str.StartsWith("'") -and $str.EndsWith("'")) -or `
                        ($str.StartsWith('"') -and $str.EndsWith('"'))
                    if ($isAlreadyQuoted) { return $str }
                    if ($AlwaysQuote -or $str.Contains(' ') -or $str.Contains("`t")) { return '"{0}"' -f $str }
                    else { return $str }
                }
                Export-ModuleMember -Function *
            } | Import-Module -Force
        }

        AfterEach {
            Remove-Module PSFzf -Force -ErrorAction SilentlyContinue
        }

        It 'starts from the buggy behavior (trailing space gets quoted)' {
            & (Get-Module PSFzf) { FixCompletionResult 'account ' } | Should -BeExactly '"account "'
        }

        It 'trims the trailing space so the candidate is no longer quoted' {
            & (Get-Module $script:Module) { Repair-PsFzfCompletionQuoting }
            & (Get-Module PSFzf) { FixCompletionResult 'account ' } | Should -BeExactly 'account'
        }

        It 'still quotes a value with an interior space (real paths unaffected)' {
            & (Get-Module $script:Module) { Repair-PsFzfCompletionQuoting }
            & (Get-Module PSFzf) { FixCompletionResult 'Program Files' } | Should -BeExactly '"Program Files"'
        }

        It 'leaves an already-clean candidate unchanged' {
            & (Get-Module $script:Module) { Repair-PsFzfCompletionQuoting }
            & (Get-Module PSFzf) { FixCompletionResult 'branch' } | Should -BeExactly 'branch'
        }
    }
}
