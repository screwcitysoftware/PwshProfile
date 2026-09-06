<#
    Shared AST-parsing helper for the catalog anti-drift tests. Not a *.Tests.ps1 file, so Pester's
    default discovery does not run it directly — each test file dot-sources it from its own BeforeAll.
#>

function Find-PwshProfileCommandAst {
    <#
    .SYNOPSIS
        Parses one or more .ps1 files and returns every call to a given command found in them.

    .DESCRIPTION
        Shared by Tests/ToolCatalog.Tests.ps1 (Install-WingetPackageSafe calls in one enabler file) and
        Tests/ModuleCatalog.Tests.ps1 (Import-ModuleSafe calls across the whole module). Parsed via the
        AST rather than grepped: the AST sees only code, so a plain-text match inside a comment-based
        help block can't be mistaken for a real call site.

    .PARAMETER Path
        One or more .ps1 file paths to parse.

    .PARAMETER CommandName
        The command name to find calls to.

    .EXAMPLE
        Find-PwshProfileCommandAst -Path $file.FullName -CommandName 'Install-WingetPackageSafe'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Path,

        [Parameter(Mandatory)]
        [string]$CommandName
    )

    foreach ($file in $Path) {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$null, [ref]$null)
        $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.GetCommandName() -eq $CommandName
            }, $true)
    }
}
