function Enable-Git {
    <#
    .SYNOPSIS
        Installs (if necessary) git, the version-control CLI, for the session.

    .DESCRIPTION
        git underpins several other profile features — posh-git's status prompt, PSFzf's Ctrl+G git
        chords, lazygit, and the GitHub CLI — none of which are useful without git on PATH. This
        enabler makes git always-on (like oh-my-posh), so those features have their dependency.

        Runs two nested Invoke-Step substeps:
          - Install: if git.exe isn't on PATH, installs it with winget (Git.Git). Unlike the portable
            tool packages, Git.Git is a full installer that lands in %ProgramFiles%\Git\cmd (a machine
            install), so an explicit -PathDir is passed (the winget Links default is wrong for it) and
            the current session's PATH is patched so git is usable immediately.
          - Initialize: a Get-Command-guarded no-op. git ships no PowerShell shell-init or
            tab-completion script of its own (the GitHub CLI's completion is handled separately by
            Enable-GithubCliCompletion), so there's nothing to run. The substep exists only to keep the
            install/initialize shape consistent with the other tool enablers and to gate on the exe
            being present.

        The install is short-circuited when git.exe already resolves, so machines that already have
        git (nearly all) never pay for it. A machine install may require elevation; if the install
        doesn't produce git.exe on PATH, a warning is emitted (with winget's captured output) so
        profile startup continues either way.

    .EXAMPLE
        Enable-Git

    .NOTES
        Version control CLI (https://git-scm.com). git has no built-in PowerShell completion, so this
        is install-only — there is no Enable-GitCompletion and no completion is registered here.
    #>
    [CmdletBinding()]
    param()

    Invoke-Step "Install" {
        # Git.Git is a full installer (not a winget portable): its exe lands in %ProgramFiles%\Git\cmd,
        # so pass that as -PathDir rather than relying on the default portable Links dir.
        Install-WingetPackageSafe -Id 'Git.Git' -Exe 'git.exe' -CallerName 'Enable-Git' -PathDir (Join-Path $env:ProgramFiles 'Git\cmd')
    }

    Invoke-Step "Initialize" {
        if (Get-Command git.exe -ErrorAction SilentlyContinue) {
            # No-op: git has no PowerShell init/completion script to run. Just having git.exe on PATH
            # is enough for posh-git, PSFzf's git chords, lazygit, and gh.
        }
    }
}
