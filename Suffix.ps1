# The module renders through PwshSpectreConsole (Invoke-Step, Write-Figlet); ensure it is present.
# Runs after every function is defined, so Import-ModuleSafe itself is available.
Import-ModuleSafe PwshSpectreConsole
