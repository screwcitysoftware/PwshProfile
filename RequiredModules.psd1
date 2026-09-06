@{
    # Dev-dependency pins, read by build.ps1's Invoke-Bootstrap. Pinned to EXACT versions so
    # "clean locally" == "clean in CI" (see build.ps1's Bootstrap doc comment for why).
    #
    # GitVersion.Tool is NOT listed here — it's a dotnet tool, not a PowerShell module, and is
    # pinned separately via .config/dotnet-tools.json (restored by `dotnet tool restore`).
    Pester           = '6.1.0'
    PSScriptAnalyzer = '1.25.0'
    ModuleBuilder    = '3.2.18'
}
