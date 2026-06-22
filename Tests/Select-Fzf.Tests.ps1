#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'

    # Two distinct objects to select among. `Name` drives display, `Id` is a projectable value.
    $script:Items = @(
        [pscustomobject]@{ Name = 'alpha'; Id = 1 }
        [pscustomobject]@{ Name = 'beta';  Id = 2 }
    )
    # Select-Fzf joins "<index><US><display>" with ASCII Unit Separator (0x1f). Mock bodies and
    # parameter filters run in module scope (they can't see a test-local variable), so the separator
    # is spelled inline as [char]0x1f throughout.
}

Describe 'Select-Fzf' {
    Context 'return values' {
        It 'returns the whole original object by default' {
            # fzf "selects" index 1 (beta); the text after the separator is irrelevant — only the index is parsed.
            Mock -ModuleName $script:Module Invoke-FzfRaw { "1$([char]0x1f)whatever" }
            $result = $script:Items | Select-Fzf -Display Name
            $result.Name | Should -Be 'beta'
            $result.Id   | Should -Be 2
        }

        It 'projects a property name via -Value' {
            Mock -ModuleName $script:Module Invoke-FzfRaw { "0$([char]0x1f)x" }
            $result = $script:Items | Select-Fzf -Display Name -Value Id
            $result | Should -Be 1
        }

        It 'projects a scriptblock via -Value' {
            Mock -ModuleName $script:Module Invoke-FzfRaw { "1$([char]0x1f)x" }
            $result = $script:Items | Select-Fzf -Display Name -Value { $_.Id * 10 }
            $result | Should -Be 20
        }

        It 'uses the item string form when -Display is omitted' {
            Mock -ModuleName $script:Module Invoke-FzfRaw { "1$([char]0x1f)x" }
            $result = 'x', 'y' | Select-Fzf
            $result | Should -Be 'y'
        }

        It 'returns an array of selections under -Multiple' {
            Mock -ModuleName $script:Module Invoke-FzfRaw { @("0$([char]0x1f)a", "1$([char]0x1f)b") }
            $result = $script:Items | Select-Fzf -Display Name -Multiple
            $result.Count    | Should -Be 2
            $result[0].Name  | Should -Be 'alpha'
            $result[1].Name  | Should -Be 'beta'
        }

        It 'returns an array under -Multiple even for a single marked row' {
            # A lone selection under -Multiple must still be an array, as the help/README promise —
            # otherwise a caller's `.Count` would read the scalar's string length.
            Mock -ModuleName $script:Module Invoke-FzfRaw { "1$([char]0x1f)b" }
            $result = $script:Items | Select-Fzf -Display Name -Multiple
            # Assert via property access, not `$result | Should` — piping would enumerate the array
            # and hide the very wrapping this test exists to verify.
            $result -is [array] | Should -BeTrue
            $result.Count       | Should -Be 1
            $result[0].Name     | Should -Be 'beta'
        }
    }

    Context 'display rendering' {
        It 'builds index-separated display lines from a property name' {
            Mock -ModuleName $script:Module Invoke-FzfRaw { "0$([char]0x1f)x" }
            $script:Items | Select-Fzf -Display Name | Out-Null
            Should -Invoke -ModuleName $script:Module Invoke-FzfRaw -Times 1 -ParameterFilter {
                $InputLine -contains "0$([char]0x1f)alpha" -and $InputLine -contains "1$([char]0x1f)beta"
            }
        }

        It 'builds display lines from a scriptblock' {
            Mock -ModuleName $script:Module Invoke-FzfRaw { "0$([char]0x1f)x" }
            $script:Items | Select-Fzf -Display { "{0}#{1}" -f $_.Name, $_.Id } | Out-Null
            Should -Invoke -ModuleName $script:Module Invoke-FzfRaw -Times 1 -ParameterFilter {
                $InputLine -contains "0$([char]0x1f)alpha#1"
            }
        }

        It 'preserves tabs/colons but collapses newlines and the separator char' {
            # The 0x1f separator can not collide with display text, so tabs and colons survive; only
            # newlines (which would split one item across lines) and a stray separator are collapsed.
            Mock -ModuleName $script:Module Invoke-FzfRaw { "0$([char]0x1f)x" }
            $weird = [pscustomobject]@{ Name = "a`tb:c`r`nd$([char]0x1f)e" }
            $weird | Select-Fzf -Display Name | Out-Null
            Should -Invoke -ModuleName $script:Module Invoke-FzfRaw -Times 1 -ParameterFilter {
                $InputLine[0] -eq "0$([char]0x1f)a`tb:c  d e"
            }
        }
    }

    Context 'fzf arguments' {
        It 'scopes display+search to the text column via --with-nth and passes no --nth' {
            # --with-nth=2.. both shows and searches the display column; a --nth would index the
            # post---with-nth view and break matching, so it must NOT be passed.
            Mock -ModuleName $script:Module Invoke-FzfRaw { "0$([char]0x1f)x" }
            $script:Items | Select-Fzf -Display Name | Out-Null
            Should -Invoke -ModuleName $script:Module Invoke-FzfRaw -Times 1 -ParameterFilter {
                $Argument -contains '--ansi' -and
                $Argument -contains "--delimiter=$([char]0x1f)" -and
                $Argument -contains '--with-nth=2..' -and
                $Argument -contains '--height=~100%' -and
                -not ($Argument | Where-Object { $_ -like '--nth=*' })
            }
        }

        It 'forwards -Multiple, -Prompt, -Header and -FzfArgument' {
            Mock -ModuleName $script:Module Invoke-FzfRaw { "0$([char]0x1f)x" }
            $script:Items | Select-Fzf -Display Name -Multiple -Prompt 'pick> ' `
                -Header 'choose' -FzfArgument '--cycle' | Out-Null
            Should -Invoke -ModuleName $script:Module Invoke-FzfRaw -Times 1 -ParameterFilter {
                $Argument -contains '--multi' -and
                $Argument -contains '--prompt=pick> ' -and
                $Argument -contains '--header=choose' -and
                $Argument -contains '--cycle'
            }
        }
    }

    Context 'edge cases' {
        It 'returns nothing and never calls fzf on empty input' {
            Mock -ModuleName $script:Module Invoke-FzfRaw { "0$([char]0x1f)x" }
            $result = @() | Select-Fzf -Display Name
            $result | Should -BeNullOrEmpty
            Should -Invoke -ModuleName $script:Module Invoke-FzfRaw -Times 0
        }

        It 'returns nothing when the user cancels (fzf yields no line)' {
            Mock -ModuleName $script:Module Invoke-FzfRaw { @() }
            $result = $script:Items | Select-Fzf -Display Name
            $result | Should -BeNullOrEmpty
        }

        It 'ignores an out-of-range index from fzf' {
            Mock -ModuleName $script:Module Invoke-FzfRaw { "99$([char]0x1f)x" }
            $result = $script:Items | Select-Fzf -Display Name
            $result | Should -BeNullOrEmpty
        }
    }

    # Runs the REAL fzf (no mock) in non-interactive --filter mode, exercising the actual fzf argument
    # semantics that the mocked tests can't see. This is the regression guard for the search-the-index
    # bug: the broken --nth=2.. arg made queries match the wrong field, which only real fzf reveals.
    Context 'live fzf matching' -Skip:(-not (Get-Command fzf.exe -ErrorAction SilentlyContinue)) {
        It 'matches on the display text and returns the corresponding object' {
            $result = $script:Items | Select-Fzf -Display Name -FzfArgument '--filter=beta'
            @($result).Count | Should -Be 1
            $result.Name     | Should -Be 'beta'
            $result.Id       | Should -Be 2
        }

        It 'does not match the hidden index column' {
            # '1' is the internal index of the 'beta' row; searching it must find nothing.
            $result = $script:Items | Select-Fzf -Display Name -FzfArgument '--filter=1'
            $result | Should -BeNullOrEmpty
        }
    }
}
