#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'ScrewCitySoftware.PwshProfile.psd1') -Force
    $script:Module = 'ScrewCitySoftware.PwshProfile'
    . (Join-Path $PSScriptRoot 'CommandAst.Helpers.ps1')

    # --- Anti-drift helpers, shared by the two checks below ---------------------------------------

    # Token -> function is by convention (Enable-<Token>), with one deliberate exception: Fnm's
    # enabler is spelled out as Enable-FastNodeManager.
    function Get-EnablerName {
        param($Token)
        $override = @{ Fnm = 'Enable-FastNodeManager' }
        if ($override.ContainsKey($Token)) { $override[$Token] } else { "Enable-$Token" }
    }

    # Searched under Public/ rather than joined onto Public/Tools: Enable-OhMyPosh lives in
    # Public/Prompt, and a hardcoded directory would fail on it before any content check ran.
    function Get-EnablerPath {
        param($Name)
        $found = @(Get-ChildItem -Path (Join-Path $PSScriptRoot '..' 'Public') -Recurse -File -Filter "$Name.ps1")
        if ($found.Count -eq 1) { $found[0].FullName }
    }

    function Get-InstallCallAst {
        param($Path)
        if (-not $Path) { return $null }
        @(Find-PwshProfileCommandAst -Path $Path -CommandName 'Install-WingetPackageSafe')[0]
    }

    # The value the enabler would actually pass for -<Name>: the argument expression is lifted out of
    # its own source and evaluated, so a Join-Path against an environment variable compares equal to
    # the catalog's already-resolved string. $null when the enabler passes no such parameter.
    function Get-CallArgumentValue {
        param($Call, $Name)
        $elements = @($Call.CommandElements)
        for ($i = 0; $i -lt $elements.Count - 1; $i++) {
            if ($elements[$i] -is [System.Management.Automation.Language.CommandParameterAst] -and
                $elements[$i].ParameterName -eq $Name) {
                $value = $elements[$i + 1]
                # A bare word (-Scope user) parses as a constant; evaluating its text as script would
                # try to RUN it. Anything else -- (Join-Path $env:ProgramFiles 'Git\cmd') -- is real
                # code and has to be executed to compare with the catalog's resolved value.
                if ($value -is [System.Management.Automation.Language.ConstantExpressionAst]) { return $value.Value }
                return @([scriptblock]::Create($value.Extent.Text).Invoke())[0]
            }
        }
        $null
    }
}

Describe 'Get-PwshProfileToolCatalog' {
    It 'groups features as Core then WinGet' {
        $sections = & (Get-Module $script:Module) { Get-PwshProfileToolCatalog }
        @($sections.Keys) | Should -Be @('Core', 'WinGet')
    }

    It 'the WinGet group is exactly the winget-install entries' {
        $sections = & (Get-Module $script:Module) { Get-PwshProfileToolCatalog }
        @($sections['WinGet'] | Where-Object { $_.Install -ne 'winget' }) | Should -BeNullOrEmpty
        @($sections['WinGet'].Token) | Should -Be @('Git', 'OhMyPosh', 'Zoxide', 'Fzf', 'Fnm', 'Xh', 'Jq', 'Bat', 'Fd', 'Ripgrep', 'Less', 'Lazygit', 'Uv')
    }

    It 'the Core group is exactly the non-winget entries' {
        $sections = & (Get-Module $script:Module) { Get-PwshProfileToolCatalog }
        @($sections['Core'] | Where-Object { $_.Install -eq 'winget' }) | Should -BeNullOrEmpty
        @($sections['Core'].Token) | Should -Be @('PSReadLine', 'TerminalIcons', 'PoshGit', 'Completions')
    }

    It 'every feature row carries a Label, Token, and a valid Install kind' {
        $sections = & (Get-Module $script:Module) { Get-PwshProfileToolCatalog }
        foreach ($key in $sections.Keys) {
            foreach ($f in $sections[$key]) {
                $f.Label | Should -Not -BeNullOrEmpty
                $f.Token | Should -Not -BeNullOrEmpty
                $f.Install | Should -BeIn @('winget', 'module', 'none')
            }
        }
    }

    It 'includes jq among the WinGet tokens' {
        $tokens = & (Get-Module $script:Module) { Get-PwshProfileToolCatalog -Token }
        $tokens | Should -Contain 'Jq'
    }

    It 'includes ripgrep among the WinGet tokens' {
        $tokens = & (Get-Module $script:Module) { Get-PwshProfileToolCatalog -Token }
        $tokens | Should -Contain 'Ripgrep'
    }

    It 'includes lazygit among the WinGet tokens' {
        $tokens = & (Get-Module $script:Module) { Get-PwshProfileToolCatalog -Token }
        $tokens | Should -Contain 'Lazygit'
    }

    It 'includes uv among the WinGet tokens' {
        $tokens = & (Get-Module $script:Module) { Get-PwshProfileToolCatalog -Token }
        $tokens | Should -Contain 'Uv'
    }

    It 'has no tool-selection parameters left on Initialize-PwshProfile' {
        # Every tool always runs. This is a tripwire against reintroducing an opt-in parameter without
        # also restoring the catalog<->ValidateSet anti-drift check that used to guard it.
        #
        # Still absent by design even though old profiles pass them: they are absorbed by
        # Initialize-PwshProfile's ValueFromRemainingArguments catch-all and named in
        # $script:RetiredParameter, so a stale block warns rather than throwing. That shim adds no
        # parameter by these names, which is why this assertion survives it unchanged.
        $p = (Get-Command Initialize-PwshProfile).Parameters
        $p.ContainsKey('Enable') | Should -BeFalse
        $p.ContainsKey('EnableAll') | Should -BeFalse
    }

    It 'carries PackageId and Exe on exactly the winget rows' {
        $sections = & (Get-Module $script:Module) { Get-PwshProfileToolCatalog }
        $rows = @(foreach ($k in $sections.Keys) { $sections[$k] })
        foreach ($row in $rows) {
            if ($row.Install -eq 'winget') {
                $row.PackageId | Should -Not -BeNullOrEmpty -Because "'$($row.Token)' is a winget install"
                $row.Exe | Should -Not -BeNullOrEmpty -Because "'$($row.Token)' is a winget install"
            }
            else {
                $row.PackageId | Should -BeNullOrEmpty -Because "'$($row.Token)' is not a winget install"
                $row.Exe | Should -BeNullOrEmpty -Because "'$($row.Token)' is not a winget install"
            }
        }
    }

    It 'carries PathDir and Scope only where the package needs its own' {
        # A portable takes Install-WingetPackageSafe's shared-Links default; setting either column on
        # one would move it somewhere winget never puts it. The full installers are the exceptions.
        $sections = & (Get-Module $script:Module) { Get-PwshProfileToolCatalog }
        $rows = @(foreach ($k in $sections.Keys) { $sections[$k] })
        foreach ($row in $rows) {
            if ($row.Token -notin @('Git', 'OhMyPosh')) {
                $row.PathDir | Should -BeNullOrEmpty -Because "'$($row.Token)' installs to the default portable dir"
                $row.Scope | Should -BeNullOrEmpty -Because "'$($row.Token)' takes winget's default scope"
            }
        }
        $git = $sections['WinGet'] | Where-Object { $_.Token -eq 'Git' }
        $git.PathDir | Should -Not -BeNullOrEmpty
        # No Scope: Git.Git is a machine install, and winget's default is what the enabler relies on.
        $git.Scope | Should -BeNullOrEmpty
        $omp = $sections['WinGet'] | Where-Object { $_.Token -eq 'OhMyPosh' }
        $omp.PathDir | Should -Not -BeNullOrEmpty
        $omp.Scope | Should -Be 'user'
    }

    It 'carries a well-formed Url on every row except Completions' {
        # Completions bundles six unrelated CLIs' own tab-completers, so there is no single project to
        # link -- every other row names one real tool or module and should link to it.
        $sections = & (Get-Module $script:Module) { Get-PwshProfileToolCatalog }
        $rows = @(foreach ($k in $sections.Keys) { $sections[$k] })
        foreach ($row in $rows) {
            if ($row.Token -eq 'Completions') {
                $row.Url | Should -BeNullOrEmpty
            }
            else {
                $row.Url | Should -Match '^https://' -Because "'$($row.Token)' should link to its project"
            }
        }
    }

    It 'matches the package each Enable-* actually installs (anti-drift)' {
        # Install-PwshProfile installs from the catalog while startup installs from the enabler, so a
        # disagreement would have setup install one package and the first shell install another. This
        # replaces the catalog<->ValidateSet check that went away with -Enable.
        #
        # Token -> function is by convention (Enable-<Token>) with one deliberate exception: Fnm's
        # enabler is spelled out as Enable-FastNodeManager.
        $sections = & (Get-Module $script:Module) { Get-PwshProfileToolCatalog }
        foreach ($row in $sections['WinGet']) {
            $fn = Get-EnablerName $row.Token
            $path = Get-EnablerPath $fn
            $path | Should -Not -BeNullOrEmpty -Because "the catalog row '$($row.Token)' should map to one $fn.ps1"
            $src = Get-Content -LiteralPath $path -Raw
            $src | Should -BeLike "*'$($row.PackageId)'*" -Because "$fn should install '$($row.PackageId)'"
            $src | Should -BeLike "*'$($row.Exe)'*" -Because "$fn should probe for '$($row.Exe)'"
        }
    }

    It 'matches the install location each Enable-* actually passes (anti-drift)' {
        # PathDir cannot be compared as a source literal the way PackageId is -- the enabler builds it
        # with Join-Path against an environment variable -- so the argument EXPRESSION is lifted out of
        # the enabler's own AST and evaluated, and the result compared with the catalog's value.
        #
        # This is the check that makes git and oh-my-posh safe to carry in the catalog at all. Without
        # it, a row that dropped PathDir would have Install-PwshProfile install the package correctly
        # and then append the shared portable Links dir to PATH, so the post-install re-check would
        # warn about an install that had in fact worked.
        $sections = & (Get-Module $script:Module) { Get-PwshProfileToolCatalog }
        foreach ($row in $sections['WinGet']) {
            $fn = Get-EnablerName $row.Token
            $call = Get-InstallCallAst (Get-EnablerPath $fn)
            $call | Should -Not -BeNullOrEmpty -Because "$fn should install through Install-WingetPackageSafe"
            "$(Get-CallArgumentValue $call 'PathDir')" |
                Should -Be "$($row.PathDir)" -Because "$fn's -PathDir should match the catalog row"
            "$(Get-CallArgumentValue $call 'Scope')" |
                Should -Be "$($row.Scope)" -Because "$fn's -Scope should match the catalog row"
        }
    }

    It 'gives every token a unique, non-empty label' {
        $sections = & (Get-Module $script:Module) { Get-PwshProfileToolCatalog }
        $rows = @(foreach ($k in $sections.Keys) { $sections[$k] })
        @($rows.Token | Sort-Object -Unique).Count | Should -Be $rows.Count
        # Labels key the wizard's selection prompts back to tokens, so they must not collide either.
        @($rows.Label | Sort-Object -Unique).Count | Should -Be $rows.Count
    }
}
