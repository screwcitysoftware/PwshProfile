<p align="center">
  <img src="Assets/icon.png" alt="ScrewCitySoftware.PwshProfile icon" width="160" />
</p>

# ScrewCitySoftware.PwshProfile

[![CI](https://github.com/screwcitysoftware/PwshProfile/actions/workflows/ci.yml/badge.svg)](https://github.com/screwcitysoftware/PwshProfile/actions/workflows/ci.yml)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/ScrewCitySoftware.PwshProfile?logo=powershell&label=PSGallery)](https://www.powershellgallery.com/packages/ScrewCitySoftware.PwshProfile)
[![Downloads](https://img.shields.io/powershellgallery/dt/ScrewCitySoftware.PwshProfile?label=downloads)](https://www.powershellgallery.com/packages/ScrewCitySoftware.PwshProfile)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A small PowerShell module that holds the reusable building blocks for this profile. It is
imported at the top of `Microsoft.PowerShell_profile.ps1`; the functions it exports are then
used throughout profile startup.

It's intentionally opinionated: built first for the author's own terminal workflow, with defaults
chosen to suit that setup rather than to cover every preference. Shared in case it's useful — fork
or cherry-pick what fits.

> **A note on provenance.** This project was vibe coded with the help of [Claude](https://claude.com/claude-code).
> The author supplied the taste, the bad ideas, and the final say; Claude supplied the typing, the
> tests, and the occasional "are you sure about that?" Any elegance is collaborative; any remaining
> bugs were a human decision.

## About the name

"ScrewCitySoftware" nods to **Screw City** — a nickname for **Rockford, Illinois**, where the
author grew up. Around the turn of the 20th century, Rockford became a major manufacturing center
for screws, fasteners, furniture, and machine tools, and the nickname stuck. The 🔩
(`:nut_and_bolt:`) `Invoke-Step` icon is a nod to that history, and the default banner reads
"Screw City".

Rockford is **also** known as the **Forest City** — for the elms and shade trees that once lined
its streets and parks along the Rock River. The module leans into that dual identity with two
bundled oh-my-posh themes: **`screwcity`** (the original — purples and blues, signature
`#c9aaff`) and **`forestcity`** (greens, browns, and grays, signature `#8fce72`). Each theme
carries a matching banner color and step icon, so picking `forestcity` renders the banner in the
theme's green with a 🌳 (`:deciduous_tree:`) step marker, while `screwcity` keeps the 🔩 / purple
identity. (The banner *text* defaults to your machine name for either theme.) See
[Themes](#themes) for how to choose one.

## Installation

### Requirements

- **PowerShell 7.4+** (`pwsh`) — 7.4 is the first release that ships
  `Microsoft.PowerShell.PSResourceGet` (`Install-PSResource`) in the box, which the module uses to
  self-install its dependencies. It won't load under Windows PowerShell 5.1.
- **Windows with [winget](https://learn.microsoft.com/windows/package-manager/winget/)** — the
  `Enable-*` tool steps install oh-my-posh, zoxide, fzf, fnm, xh, jq, bat, fd, and less through the
  first-party `Microsoft.WinGet.Client` module (auto-installed CurrentUser the first time a tool is
  missing; winget ships with Windows 11). Without winget those steps degrade silently; the rest of
  startup is unaffected.
- **A Nerd Font** in your terminal — the oh-my-posh prompt and Terminal-Icons render powerline
  glyphs and file icons that only display correctly in a Nerd Font (see below).
- [PwshSpectreConsole](https://www.powershellgallery.com/packages/PwshSpectreConsole) is
  **installed automatically** on first import (the module calls `Import-ModuleSafe
  PwshSpectreConsole`), so there's no manual step for it.
- **Runtime PowerShell modules** — Terminal-Icons (file icons), posh-git (git status in the prompt),
  and [PSFzf](https://github.com/kelleyma49/PSFzf) (fzf's Ctrl+T/Ctrl+R key bindings on Windows —
  distinct from the fzf CLI installed via winget) are auto-installed from PSGallery on first use via
  `Import-ModuleSafe`. Each failure is non-fatal, so startup continues if one can't install.

### Install the module

From the PowerShell Gallery:

```powershell
Install-PSResource ScrewCitySoftware.PwshProfile
```

### Set up your profile (recommended)

Once the module is installed, the easiest way to wire it into your shell is the
**`Install-PwshProfile`** wizard — run it once and it writes the bootstrap into your `$PROFILE`
for you (creating the file if needed, preserving any existing code), and can optionally install the
Nerd Fonts and show how to point your terminal at them:

```powershell
Install-PwshProfile        # interactive wizard
```

To remove the bootstrap later, run `Uninstall-PwshProfile` (it leaves your installed tools and
fonts in place). For more on what the wizard writes and how to call the orchestrator yourself, see
[Usage](#usage). The Nerd Font and terminal steps below are the manual equivalents of what the
wizard offers.

### Install a Nerd Font

> The `Install-PwshProfile` wizard can install these for you and then show the terminal-config
> steps (`Show-NerdFontSetup`). The steps below are the manual route.

The prompt and icons need a Nerd Font. Install Meslo and Cascadia Code with the
[NerdFonts](https://www.powershellgallery.com/packages/NerdFonts) module:

```powershell
Install-PSResource NerdFonts
Install-NerdFont -Name 'Meslo', 'CascadiaCode' -Scope CurrentUser -Variant Standard
```

This registers Nerd Font faces named **MesloLGM Nerd Font** and **CaskaydiaCove Nerd Font**
(Nerd Fonts' patched name for Cascadia Code). Use one of those face names when configuring your
terminal.

### Configure your terminal/editor to use the font

**Windows Terminal** — Settings → select your profile → Appearance → Font face →
*MesloLGM Nerd Font* (or *CaskaydiaCove Nerd Font*). The equivalent `settings.json` edit:

```jsonc
// Windows Terminal settings.json — per profile (or under "profiles": { "defaults": { ... } })
"font": { "face": "MesloLGM Nerd Font" }
```

**VS Code** — add to `settings.json` (set the integrated terminal font; optionally the editor too):

```jsonc
"terminal.integrated.fontFamily": "MesloLGM Nerd Font, CaskaydiaCove Nerd Font",
"editor.fontFamily": "MesloLGM Nerd Font, CaskaydiaCove Nerd Font, Consolas, monospace"
```

## Usage

The recommended way to wire this into your shell is the **`Install-PwshProfile`** wizard — run
it once and it writes the bootstrap into your `$PROFILE` (and can install the Nerd Fonts and show the
terminal setup). To remove it, run **`Uninstall-PwshProfile`**:

```powershell
Install-PwshProfile        # interactive wizard; re-run any time to change options
Uninstall-PwshProfile      # remove the bootstrap (installed tools/fonts are left in place)
```

The bootstrap it writes is a `# Tools available:` snapshot comment plus a call to
**`Initialize-PwshProfile`** — the orchestrator that runs on every new session. There's no
`Import-Module` line: invoking `Initialize-PwshProfile` auto-loads the module. Tool selection is
**opt-in** — you call it with the tools you want:

```powershell
Initialize-PwshProfile -Enable Zoxide,Fzf,Bat,Fd   # only these tools run
```

A few common variations:

```powershell
Initialize-PwshProfile -Enable Zoxide,Bat -BannerColor Green -BannerAlignment Center
Initialize-PwshProfile -EnableAll                  # every tool, plus any added in future updates
Initialize-PwshProfile -EnableAll -NoBanner        # everything, no startup banner
```

A **bare** `Initialize-PwshProfile` has no selection: interactively it asks whether to enable all
tools, and non-interactively it enables none — so prefer `-Enable`/`-EnableAll` (the wizard always
writes one of them). `Initialize-PwshProfile` takes a handful of other options — banner text/color/font,
a custom theme — all covered under [Exported functions](#exported-functions).

Changing the managed block is best done by **re-running `Install-PwshProfile`** rather than editing
the call by hand — on a re-run the installer reads the call and the tools snapshot to pre-fill your
prior choices and flag newly-added tools, so it stays the source of truth for your setup.

### Assembling startup yourself (advanced)

Most people never need this — `Initialize-PwshProfile` is the supported entry point. But if you want
to assemble a custom startup yourself, you can call the individual building blocks directly instead:

```powershell
Write-Figlet 'Screw City' -Font ANSIShadow  # figlet banner in a bundled font
Invoke-Step "PSReadLine"      { Initialize-PSReadline }
Invoke-Step "Terminal-Icons"  { Import-ModuleSafe Terminal-Icons -Repair { Repair-TerminalIconsCache } }
```

Full comment-based help is available on each function via `Get-Help <Name> -Full`.

## Using the tools

Enabling a tool changes how some everyday commands behave. Here's a quick orientation for each —
just enough to get going; every one of them has more under `<tool> --help`.

### zoxide — a smarter `cd`

By default zoxide takes over `cd`. It remembers the directories you visit, so after you've been
somewhere once you can jump back by any part of its name instead of typing the full path:

```powershell
cd proj          # jump to the most-used directory matching "proj"
cd src test      # match a directory whose path contains both fragments
cdi              # interactive picker (fzf) over your tracked directories
```

A plain `cd <full-path>` still works exactly as before — zoxide only adds the shortcut jumps.

### fzf — fuzzy finder (key bindings)

fzf adds interactive fuzzy pickers bound to keys in your shell (via PSFzf):

- **Ctrl+T** — fuzzy-pick a file or directory and drop its path at the cursor (with a `bat` preview).
- **Ctrl+R** — fuzzy-search your command history.
- **Ctrl+G** chords — fuzzy git pickers (files, branches, hashes, …) when you're inside a repo.
- **Ctrl+Spacebar** — fuzzy completion: opens an fzf picker over what `Tab` would complete (paths, command/parameter names, and every registered completer — `gh`, `az`, `winget`, …, all inserting cleanly). `Tab` itself stays the classic `MenuComplete` menu.

In any picker: type to filter, arrows or Tab to move, Enter to accept, Esc to cancel.

### fd — fast file find

A friendly, fast `find`. It searches by substring/regex, respects `.gitignore`, and skips hidden
files unless you ask for them:

```powershell
fd report                 # files matching "report" under the current directory
fd -e ps1                 # all .ps1 files
fd -H -e log              # include hidden files
fd pattern ./src          # search within a specific path
```

fd is standalone — it never replaces `Get-ChildItem` / `ls`.

### bat — `cat` with highlighting

Prints files with syntax highlighting, line numbers, and git change marks, paging long files through
`less`. If you turned on `-ReplaceCat`, plain `cat` *is* bat:

```powershell
bat README.md             # highlighted, paged
bat -p script.ps1         # plain output, no decorations
```

### less — the pager

The pager long output scrolls through — and what `bat`, `git`, and PowerShell's `help` page through
when `-ReplaceMore` is on. While it's open: arrows / `Space` to scroll, `/text` to search, `q` to quit.

### xh — HTTP client

A fast, friendly HTTP client (HTTPie-style). `http` and `https` are aliased to it:

```powershell
http GET httpbin.org/get                     # GET, pretty-printed JSON
https POST api.example.com/users name=jo     # POST a JSON body over HTTPS
```

### jq — JSON processor

Filters and reshapes JSON on the pipeline — pairs naturally with `xh`:

```powershell
http GET httpbin.org/json | jq '.slideshow.title'
Get-Content data.json | jq '.items[].name'
```

### fnm — Node version manager

Manages multiple Node.js versions. Every directory change automatically runs `fnm use` for you
(it hooks every change, with or without zoxide): `cd` into a folder with an `.nvmrc` or
`.node-version` and it switches to that version, reverting to your default version when you leave.
Manually:

```powershell
fnm install 20      # install Node 20
fnm use 20          # use it in this session
fnm list            # show installed versions
```

## Themes

The module bundles two oh-my-posh themes under `Assets/Themes`, both built on the same palette-keyed
structure so they differ only in color:

| Theme        | Identity      | Signature color | Step icon            | Palette                  |
|--------------|---------------|-----------------|----------------------|--------------------------|
| `screwcity`  | Screw City    | `#c9aaff` purple | 🔩 `:nut_and_bolt:`   | purples, blues, ambers   |
| `forestcity` | Forest City   | `#8fce72` green  | 🌳 `:deciduous_tree:` | greens, browns, grays    |

Each theme's identity extends past the prompt: a matching **bat** syntax theme, **fd**/**fzf**
color palettes, and a **Windows Terminal color scheme** (install it with
`Install-WindowsTerminalScheme` so the terminal's own colors match the prompt).

**The installer's first step is the theme choice.** `Install-PwshProfile` opens with a theme prompt —
pick a bundled theme or supply a path to a theme of your own — and the rest of the wizard pre-fills
its color/icon prompts from the chosen theme's branding. For a **custom theme** those prompts start
from neutral defaults (a neutral color, a generic ⚙️ icon) so you brand it fresh. The banner **text**
defaults to your machine name (`$env:COMPUTERNAME`) for every theme, custom included.
Whatever you pick is written into the generated bootstrap as `-Theme <name>` (or `-CustomTheme '<path>'`).

Choosing a theme outside the wizard, or by hand in `$PROFILE`:

```powershell
Initialize-PwshProfile -Theme forestcity                 # bundled theme + matching banner/icon
Initialize-PwshProfile -CustomTheme ~/.config/themes/custom.omp.json   # your own theme file
```

Picking a bundled theme also sets the banner color and step icon for any you don't override (the
banner text defaults to your machine name regardless of theme); running `-CustomTheme` by hand keeps
the neutral screwcity color/icon for any you don't pass (use `-NoBanner` to render no banner).

### Creating a custom theme

oh-my-posh themes are plain JSON, so the easiest way to start your own is from a copy of a bundled
theme. `Export-OhMyPoshTheme` writes that copy to a path you own (the bundled files live in a
versioned, possibly read-only install directory, so never edit them in place); `Get-OhMyPoshTheme`
emits the raw JSON to the pipeline instead, for piping to a file, the clipboard, or an editor:

```powershell
Export-OhMyPoshTheme -Path ~/my.omp.json                       # copy of screwcity (the default)
Export-OhMyPoshTheme -Theme forestcity -Path ~/forest.omp.json # start from Forest City instead
Export-OhMyPoshTheme -Path ~/my.omp.json -Force                # overwrite an existing file

Get-OhMyPoshTheme | Set-Content ~/my.omp.json                  # same, via the pipeline
Get-OhMyPoshTheme -Theme forestcity | clip                     # copy the JSON to the clipboard
```

You can edit the JSON by hand, but the easiest path is the visual configurator at
**<https://jamesmontemagno.github.io/ohmyposh-configurator/>**. It **imports an existing theme** — load
your `.omp.json` file or copy/paste its JSON — then lets you tweak segments and colors against a live
preview and export the result back out. A typical round-trip:

1. Export a starting point: `Export-OhMyPoshTheme -Path ~/my.omp.json` (or `Get-OhMyPoshTheme | clip`).
2. Open the configurator and import that file (or paste the copied JSON).
3. Adjust segments and colors visually, then download/copy the updated theme back over `~/my.omp.json`.
4. Point the module at it: `Initialize-PwshProfile -CustomTheme ~/my.omp.json` — re-run
   `Install-PwshProfile` to bake the choice into your `$PROFILE`, or
   `Enable-OhMyPosh -Configuration ~/my.omp.json` to try it in the current session.

## Layout

The module follows the standard Public/Private layout, with both trees grouped into feature
subfolders (`Install/`, `Startup/`, `Prompt/`, `Tools/`, `Rendering/`, `Docs/`, `Core/`). The
`.psm1` is a generic loader: it recursively dot-sources every `.ps1` under `Public/` (and
`Private/`, if that folder exists) and exports the public ones, so it never needs editing. The
subfolders are purely organizational — folder nesting never affects which functions are
exported (the manifest's `FunctionsToExport` stays a flat list). Each exported function lives in
its own file named after the function:

```
ScrewCitySoftware.PwshProfile/
├── ScrewCitySoftware.PwshProfile.psd1   # manifest: version, explicit FunctionsToExport list
├── ScrewCitySoftware.PwshProfile.psm1   # loader: recursively dot-sources Public/ (+ Private/), exports
├── Public/                              # one exported function per file
│   ├── Install/
│   │   ├── Install-PwshProfile.ps1   # wizard: write the bootstrap into a profile file
│   │   └── Uninstall-PwshProfile.ps1 # remove the managed bootstrap block
│   ├── Startup/
│   │   ├── Initialize-PwshProfile.ps1 # one-call default profile startup (orchestrator)
│   │   └── Initialize-PSReadline.ps1
│   ├── Prompt/
│   │   ├── Enable-OhMyPosh.ps1
│   │   ├── Get-OhMyPoshTheme.ps1          # emit the bundled oh-my-posh theme JSON
│   │   └── Export-OhMyPoshTheme.ps1       # copy the bundled theme to a file you own
│   ├── Tools/
│   │   ├── Enable-Zoxide.ps1
│   │   ├── Enable-Fzf.ps1
│   │   ├── Enable-FastNodeManager.ps1
│   │   ├── Enable-Xh.ps1
│   │   ├── Enable-Jq.ps1
│   │   ├── Enable-Bat.ps1
│   │   ├── Enable-Fd.ps1
│   │   ├── Enable-Less.ps1
│   │   ├── Set-WingetSetting.ps1          # merges client prefs (scope, progress bar, …) into winget's settings.json
│   │   ├── Select-Fzf.ps1                 # pipe objects through fzf; returns the selected object(s) (bundles its private Invoke-FzfRaw seam in-file)
│   │   └── Completions/                   # one Enable-<Tool>Completion per CLI
│   │       ├── Enable-WingetCompletion.ps1     # winget native tab completion
│   │       ├── Enable-AzureCliCompletion.ps1   # Azure CLI (az) native (argcomplete) tab completion
│   │       ├── Enable-TailscaleCompletion.ps1  # tailscale (Cobra) tab completion
│   │       ├── Enable-DockerCompletion.ps1     # docker tab completion via the DockerCompletion module
│   │       ├── Enable-1PasswordCompletion.ps1  # 1Password CLI (op, Cobra) tab completion
│   │       └── Enable-GithubCliCompletion.ps1  # GitHub CLI (gh, Cobra) tab completion
│   ├── Rendering/
│   │   ├── Invoke-Step.ps1                # Invoke-Step dispatcher (+ the module-scoped step state)
│   │   ├── Write-Figlet.ps1               # figlet banner writer
│   │   ├── Show-FigletFont.ps1            # list / preview the bundled FIGlet fonts
│   │   ├── Install-WindowsTerminalScheme.ps1    # add a theme's matching scheme to WT settings.json
│   │   └── Uninstall-WindowsTerminalScheme.ps1  # remove a theme's scheme from WT settings.json
│   ├── Docs/
│   │   ├── Show-PwshProfileReadme.ps1       # renders this README (Show-Markdown) or opens it (-Open)
│   │   └── Show-NerdFontSetup.ps1         # panel: point Windows Terminal / VS Code at a Nerd Font
│   └── Core/
│       └── Import-ModuleSafe.ps1
├── Private/                             # internal helpers (loaded, not exported)
│   ├── Install/                         # Install/Uninstall helpers: marker + block builders, the
│   │   └── *PwshProfile*.ps1       #   wizard, feature tree, file writer, defaults, call builder, and
│   │                               #   Read-PwshProfileInstalledSetting (re-run prefill parser)
│   ├── Startup/                         # opt-in resolution helpers (shared by startup + the wizard)
│   │   ├── Get-PwshProfileToolCatalog.ps1     # single source of truth for the tool token set
│   │   └── Confirm-PwshProfileEnableAll.ps1   # bare-call "enable all?" confirm (guarded, no-hang)
│   ├── Prompt/
│   │   ├── Get-BundledThemePath.ps1     # resolves Assets/Themes/<theme>.omp.json (default screwcity)
│   │   ├── Get-BundledThemeName.ps1     # lists bundled theme names (drives -Theme validation/completion)
│   │   └── Get-BundledThemeBranding.ps1 # banner + bat/fd/fzf colors + WT color scheme paired with each bundled theme
│   ├── Tools/
│   │   ├── Install-WingetPackageSafe.ps1 # shared Install step (Install-WinGetPackage) for the Enable-* enablers (-PathDir defaults to the WinGet\Links dir)
│   │   ├── Get-WingetSettingDefault.ps1  # current winget user-setting values (else module defaults) for the wizard
│   │   ├── Get-FzfVersion.ps1            # parses `fzf --version` so Enable-Fzf only adds --style on fzf 0.54+
│   │   └── Completions/
│   │       └── Register-CobraCompletion.ps1 # shared engine for Cobra CLIs (tailscale, op) — wrapped by the Enable-* enablers
│   ├── Rendering/
│   │   ├── Invoke-StepInternal.ps1      # spinner-breadcrumb worker (+ Format-StepStatus)
│   │   ├── Get-BundledFontPath.ps1      # resolves Assets/Fonts/<name>.flf
│   │   ├── Get-BundledFontName.ps1      # lists bundled font names (drives -Font validation/completion)
│   │   ├── Get-WindowsTerminalSettingsPath.ps1 # locates WT settings.json (stable/preview/unpackaged)
│   │   └── Edit-WindowsTerminalSettings.ps1    # shared read/backup/write engine for the scheme install/uninstall
│   └── Core/
│       └── Invoke-InGlobalScope.ps1     # runs tool-init output in global scope, unattributed
├── Assets/                              # bundled assets
│   ├── Themes/
│   │   ├── screwcity.omp.json   # default oh-my-posh theme — Screw City (purple/blue)
│   │   └── forestcity.omp.json  # alternate theme — Forest City (green/brown/gray)
│   └── Fonts/                           # 25 bundled FIGlet fonts (see Write-Figlet / Show-FigletFont)
│       ├── *.flf                        # ANSIShadow, Colossal, Doom, Slant, Small, ... (run Show-FigletFont)
│       └── README.md                    # font sources + license/attribution
└── Tests/                               # Pester 5 tests
```

To add a function: create `Verb-Noun.ps1` in the matching `Public/` subfolder (file name ==
function name), add the name to `FunctionsToExport` in the `.psd1`, and document it below. Pick
the subfolder by responsibility (`Tools/` for tool/completion enablers, `Prompt/` for
oh-my-posh, etc.); the loader recurses, so the exact folder is organizational only. Internal
helpers go in the matching `Private/` subfolder — the loader picks them up but does not export
them.

## Exported functions

### `Install-PwshProfile`

A one-time, re-runnable setup wizard (built on PwshSpectreConsole) that writes the module's
bootstrap — a tools snapshot comment plus a tailored `Initialize-PwshProfile` call (no `Import-Module`
line; the call auto-loads the module) — into a profile file, wrapped in managed marker comments. By
default it targets `$PROFILE`. On a re-run it reads the existing block to pre-fill your prior choices
and flag tools added since. It **wires the module into your profile file**; it does not install the
module itself from the gallery (use `Install-PSResource ScrewCitySoftware.PwshProfile` for that).

Each step opens with a rounded header panel — its title, a `step N of 6` progress counter, and a
short description — and secondary prompts carry an indented hint line beneath them (the feature step
shows a one-line-per-feature legend). The descriptions are syntax-highlighted: tool names in the
accent color, code literals (file types, commands like `cd` / `z`, paths) in cyan, body prose in soft
grey — so you don't need to already know the tools. The review/intro/result panels share the same
glyphs and highlighting. Each selection (theme, alignment, font, step icon) confirms your choice with
a `✓ <value>` line once its menu collapses.

The wizard walks one forward pass, then lets you revise anything before committing:

1. **Nerd Fonts** — a single yes/no: say yes to install the recommended Meslo + CascadiaCode pair for
   the prompt glyphs via the [NerdFonts](https://www.powershellgallery.com/packages/NerdFonts) module
   (CurrentUser scope, no admin required); say no and nothing is installed.
2. **Winget** — a few [winget](https://learn.microsoft.com/windows/package-manager/winget/) client
   settings: default install **scope** (`user` / `machine`), **progress-bar** style, whether to
   **anonymize displayed paths**, and whether to **suppress install notes**. It shows your current
   values first (noting any that differ from the recommended default) and asks whether to change them
   — **defaulting to No**, so pressing Enter keeps them and skips the per-setting prompts. The values
   are merged into your `settings.json` via [`Set-WingetSetting`](#set-wingetsetting) when you submit
   (a one-time machine change, not part of the bootstrap block; skipped under `-WhatIf`).
3. **Theme** — pick a bundled theme (`screwcity` / `forestcity`) or supply a path to a theme of
   your own (see [Themes](#themes)). The choice seeds the banner color and step icon the later prompts
   are pre-filled with; a custom path seeds neutral color/icon so you brand those fresh. The banner
   text defaults to your machine name (`$env:COMPUTERNAME`) regardless of theme.
4. **Banner** — shows the current banner config (shown/hidden plus text, color, alignment, font,
   noting anything off the theme default) and asks whether to change it — **defaulting to No**. On
   yes, a show/hide question gates the rest: say no and the banner is suppressed (`-NoBanner`) and
   the theming prompts are skipped; say yes and you're prompted for text, color, alignment, and font.
5. **Step icon** — always asked (the icon marks every startup step, banner or not), with the
   current icon floated to the top and a "custom shortcode" escape.
6. **Features** (opt-in) — first a **mode** choice: *pick specific tools*, or *enable everything
   including tools added in future updates* (emits `-EnableAll`). "Specific" shows a grouped tree under
   two sections — **Core** (PSReadLine, Terminal-Icons, posh-git, shell completions) and **WinGet** (the
   winget-installed CLIs: zoxide, fzf, fnm, xh, jq, bat, fd, less). On a re-run it **pre-checks your prior
   selection**; on a clean first run **Core is pre-checked and WinGet is left unchecked** (so the
   light-install Core stuff is on by default, but each winget install is an explicit opt-in). Tools added
   to the module since your last setup are tagged **(new)**; the checked set becomes `-Enable`.
   oh-my-posh is always on and isn't listed. If `zoxide` ends up enabled you're prompted for its jump
   command; if `bat` is enabled, whether to replace the built-in `cat` (**defaulting to Yes**, emitting
   `-ReplaceCat`); if `less` is enabled, whether to make it the default pager (**defaulting to Yes**,
   emitting `-ReplaceMore` — sets `$env:PAGER` and aliases `more` → `less`). When `fzf` is enabled it
   also gains the PSFzf Ctrl+T/Ctrl+R key bindings.

It then shows a **review** screen: **Submit** to write the profile, **Edit** any step to revise it,
or **Cancel** to exit without writing anything.

Your existing profile is never destroyed:

- A missing file (and its parent directory) is created.
- An existing **managed block** is replaced in place, so you can re-run the wizard any time to
  change options. Re-runs start from the module defaults.
- Any other existing content is preserved, with the block prepended above it.
- A profile that already has a bare `Import-Module ScrewCitySoftware.PwshProfile` (no markers) is
  left untouched unless `-Force` is given.

The file is written as UTF-8 without a BOM. The wizard is **interactive-only**: Spectre prompts only
render in an interactive console, and when they're unavailable the command warns that an interactive
session is required and makes no changes.

- **`-Path`** — the profile file to configure (default `$PROFILE`, current user / current host).
  `$PROFILE` is host-specific, so the VS Code and ISE hosts use different files.
- **`-Force`** — prepend the managed block even when the file already has a bare module import (no
  markers).
- **`-PassThru`** — emit a result object (`Path`, `Action`, `Changed`); by default the command
  returns nothing.

Supports `-WhatIf` / `-Confirm`.

```powershell
Install-PwshProfile                              # wizard → writes $PROFILE
Install-PwshProfile -WhatIf                      # walk the wizard, preview the write
Install-PwshProfile -Path $PROFILE.CurrentUserAllHosts   # the all-hosts profile
Install-PwshProfile -Path ~/Documents/PowerShell/Microsoft.VSCode_profile.ps1  # VS Code host
```

To **change settings**, just re-run `Install-PwshProfile` (it rewrites the block in place); to
**remove** the bootstrap, use [`Uninstall-PwshProfile`](#uninstall-pwshprofile).

### `Uninstall-PwshProfile`

Removes the marker-wrapped bootstrap block that `Install-PwshProfile` wrote, leaving every other
line in the profile intact. By default it targets `$PROFILE`.

It touches **only the profile file** — it does **not** uninstall any tools, Nerd Fonts, or modules
that were installed during setup; it just stops the module from initializing on future sessions. A
hand-written, unmanaged `Import-Module ScrewCitySoftware.PwshProfile` (no markers) is left untouched,
since that's your own code rather than the managed injection.

- **`-Path`** — the profile file to clean (default `$PROFILE`, current user / current host).
- **`-PassThru`** — emit a result object (`Path`, `Action` = `Removed` | `NotInstalled`, `Changed`);
  by default the command returns nothing.

Supports `-WhatIf` / `-Confirm`. If removing the block leaves the file empty, the empty file is left
in place rather than deleted.

```powershell
Uninstall-PwshProfile                            # remove the block from $PROFILE
Uninstall-PwshProfile -WhatIf                    # preview the removal
Uninstall-PwshProfile -Path $PROFILE.CurrentUserAllHosts
```

### `Show-NerdFontSetup`

Renders a panel with the exact steps to point **Windows Terminal** and **VS Code** at an installed
Nerd Font, so the oh-my-posh prompt glyphs render. `Install-PwshProfile` shows it automatically
when you choose fonts (including in a `-WhatIf` preview); run it any time to see the steps again.

It handles a common gotcha: the font **family name** you select in the terminal is not the catalog
name you install — `Meslo` installs as `MesloLGM Nerd Font`, and `CascadiaCode` as `CaskaydiaCove
Nerd Font`. Pass `-Font` with the catalog name(s) you installed and the panel names the matching
families; with no `-Font` it shows the recommended pairing. If PwshSpectreConsole isn't loaded, the
same text is written plainly.

- **`-Font`** — the Nerd Font catalog name(s) you installed (e.g. `Meslo`, `CascadiaCode`), as
  accepted by `Install-NerdFont`. Unrecognized names fall back to the recommended pairing.

```powershell
Show-NerdFontSetup                       # recommended families
Show-NerdFontSetup -Font Meslo, CascadiaCode
```

### `Initialize-PwshProfile`

The headline entry point: one call that runs the profile startup, so `$PROFILE` shrinks to just this
call (it auto-loads the module). Tool selection is **opt-in** via `-Enable`/`-EnableAll` (see below).
In order it shows the startup banner, then runs two top-level `Invoke-Step` sections split by install
model — **Core** (the `which` global alias, PSReadLine, oh-my-posh, Terminal-Icons, posh-git, and the
shell **completions** for winget/Azure CLI/Tailscale/Docker/1Password/GitHub CLI — registration only, no
installs) and **WinGet** (the CLIs installed via WinGet: zoxide, fzf, fnm, xh, jq, bat, fd, less — fzf
next to zoxide, fnm auto-switching the node version on any directory change, fd after fzf so it can wire
fzf to use fd as its source, less as bat's/PowerShell's pager). oh-my-posh and the `which` alias always run; everything
else is enabled only when listed in `-Enable` (or via `-EnableAll`). The Core section always renders; the
WinGet section renders only when at least one winget tool is enabled. Each section renders its own spinner
and summary line, and steps that depend on a missing tool degrade silently, so startup never throws. It
deliberately does **not** run your own personal extras (e.g. `Initialize-WorkTools.ps1` or `aliases.ps1`)
— those stay in `$PROFILE`.

- **`-Theme`** — the bundled oh-my-posh theme: `screwcity` (default) or `forestcity` (tab-completes,
  discovered from `Assets/Themes`). Resolved to its file and forwarded to `Enable-OhMyPosh
  -Configuration`. The choice also seeds the banner color and step icon below. Mutually
  exclusive with `-CustomTheme`.
- **`-CustomTheme`** — path (relative or absolute) to a custom oh-my-posh theme, forwarded to
  `Enable-OhMyPosh -Configuration` in place of a bundled theme. Validated to exist at call time.
  Mutually exclusive with `-Theme`; banner color/icon fall back to the screwcity defaults.
- **`-BannerText`** — banner text (defaults to your machine name, `$env:COMPUTERNAME`, for every
  theme; must be non-empty — use `-NoBanner` to render no banner).
- **`-BannerColor`** — any Spectre color name or hex (defaults to the theme's signature color —
  `#c9aaff` / `#8fce72`).
- **`-BannerAlignment`** — `Left`, `Center`, or `Right` (default `Left`).
- **`-BannerFont`** — a bundled FIGlet font for the banner, forwarded to `Write-Figlet -Font`
  (see `Write-Figlet` for the list). Mutually exclusive with `-BannerFontPath`.
- **`-BannerFontPath`** — path to a custom `.flf` font for the banner, forwarded to
  `Write-Figlet -FontPath`. Mutually exclusive with `-BannerFont`.
- **`-ZoxideCommand`** — zoxide's jump command, forwarded to `Enable-Zoxide -Command` (default
  `cd`; pass e.g. `z` to keep the built-in `cd`).
- **`-BatTheme`** — bat's syntax theme, forwarded to `Enable-Bat -Theme` (sets `$env:BAT_THEME`).
  Defaults to the active theme's blend (`Dracula` for screwcity, `gruvbox-dark` for forestcity); a
  value from `bat --list-themes`.
- **`-BatStyle`** — bat's layout, forwarded to `Enable-Bat -Style` (sets `$env:BAT_STYLE`); default
  `numbers,changes,header`.
- **`-ReplaceCat`** — forwarded to `Enable-Bat -ReplaceCat`: aliases `cat` → `bat` for the session
  (replacing the built-in `cat`, an alias for `Get-Content`). Off by default.
- **`-ReplaceMore`** — forwarded to `Enable-Less -ReplaceMore`: sets `$env:PAGER` to `less` (so
  PowerShell's `help`, `bat`, `git`, `delta`, and `gh` page through less instead of `more.com`) and
  aliases `more` → `less` for the session. Off by default.
- **`-FdColors`** — fd's `LS_COLORS` palette, forwarded to `Enable-Fd -LsColors` (sets
  `$env:LS_COLORS`). Defaults to the active theme's blend (purple-led for screwcity, green-led for
  forestcity). fd stays standalone — it never replaces `Get-ChildItem`. (`LS_COLORS` is shared with
  `ls`/`eza`.)
- **`-FzfColors`** — fzf's picker palette, forwarded to `Enable-Fzf -Colors` (folded into
  `$env:FZF_DEFAULT_OPTS`). Defaults to the active theme's blend (purple/cyan for screwcity,
  green/gold for forestcity).
- **`-StepIcon`** — the top-level step marker, forwarded to `Invoke-Step -Icon` (defaults to the
  theme's branding — `:nut_and_bolt:` → 🔩 for screwcity, `:deciduous_tree:` → 🌳 for forestcity).
  No trailing space needed — the separator before the step text is added at render time.
- **`-Enable`** — the tools to enable (opt-in): any of `PSReadLine`, `TerminalIcons`, `PoshGit`,
  `Zoxide`, `Fzf`, `Fnm`, `Xh`, `Jq`, `Bat`, `Fd`, `Less`, `Completions`. Only the listed tools run
  (and the auto-installing ones install), so a tool added in a later module version never installs
  unless you add it here. `-Enable @()` enables nothing. oh-my-posh and the `which` alias always run
  and are not tokens.
- **`-EnableAll`** — enable every tool in the catalog, including any added in future module versions
  (opts into auto-installing future tools). If both `-EnableAll` and `-Enable` are given, `-Enable`
  wins (the explicit list is the safer choice) and a warning notes `-EnableAll` was ignored.
- **`-NoBanner`** — render no startup banner. Use this to suppress the banner rather than clearing
  `-BannerText` (which rejects empty); banner params passed alongside it are warned-and-ignored.

A tool-specific parameter (e.g. `-ReplaceCat`, `-ZoxideCommand`) for a tool that isn't enabled is
warned about and ignored rather than throwing — and a wizard-generated call only ever emits one for an
enabled tool.

```powershell
Initialize-PwshProfile -Enable Zoxide,Bat,Fd            # Screw City theme; only these tools
Initialize-PwshProfile -Theme forestcity -EnableAll     # Forest City theme; every tool + future ones
Initialize-PwshProfile -Enable Zoxide,Bat -BannerColor Green -BannerAlignment Center
Initialize-PwshProfile -EnableAll -BannerFont ANSIShadow            # large block banner font
Initialize-PwshProfile -CustomTheme ~/.config/themes/custom.omp.json -Enable Zoxide
Initialize-PwshProfile -EnableAll -NoBanner             # no startup banner
Initialize-PwshProfile -Enable Bat -ReplaceCat          # alias cat -> bat (themed syntax highlighting)
Initialize-PwshProfile -Enable Less -ReplaceMore        # make less the default pager (replace more.com)
```

### `Invoke-Step`

Runs a named startup step, rendered with PwshSpectreConsole. While running, the top-level
call shows a transient status spinner; nested steps update its text to the full breadcrumb
path (e.g. `⠼ 🔩 WinGet › fnm › Install`), restoring the parent's path when they finish. When
the top-level step completes, the spinner clears itself and a single summary line is written
with the total elapsed time — nested substeps leave no output of their own:

```
🔩 Core............................................ [ 920ms]
🔩 WinGet.......................................... [3120ms]
```

Only the top-level step's icon is shown. If PwshSpectreConsole isn't loaded, steps still run
— silently, with no rendering — so startup never fails over presentation.

A `Write-Warning` raised inside a step (e.g. a module that fails to load) would otherwise be
wiped off-screen when the spinner clears. Instead, warnings are captured while the spinner
runs and re-printed underneath the step's summary line, so they stay readable in scrollback:

```
🔩 Core............................................ [ 880ms]
WARNING: Import-ModuleSafe: could not import 'Terminal-Icons': <reason>
```

Each *top-level* `Invoke-Step` opens its own spinner and writes its own summary line; wrap
the whole startup in one outer step (`Invoke-Step "Profile" { ... }`) for a single continuous
spinner and exactly one summary line.

```powershell
Invoke-Step "Terminal-Icons" { Import-ModuleSafe Terminal-Icons -Repair { Repair-TerminalIconsCache } }

Invoke-Step "Completions" {
    Invoke-Step "Tailscale" { Enable-TailscaleCompletion }
}
```

### `Import-ModuleSafe`

Imports a module, installing it first (`Install-PSResource`, CurrentUser scope, PSGallery by
default) if it isn't already available. Install/import failures are reported as warnings and
swallowed so profile startup continues. An optional `-Initialize` script block runs once the
module has imported successfully. An optional `-Repair` script block runs when the import fails;
the import is then retried once, and a warning is only reported if that retry also fails — used to
clean up state that wedges a module's import (e.g. `Repair-TerminalIconsCache`, which purges a
corrupted Terminal-Icons theme cache so the re-import can regenerate it).

```powershell
Import-ModuleSafe Terminal-Icons -Repair { Repair-TerminalIconsCache }
Import-ModuleSafe posh-git -Initialize { $env:POSH_GIT_ENABLED = $true }
```

### `Initialize-PSReadline`

Configures PSReadLine for the session: history options, prediction source/view, edit mode,
bell style, and key handlers. `UpArrow`/`DownArrow` do history search; `Tab` triggers menu
completion (a navigable list of completions); `Alt+w` saves the current line to history without
executing it; `Alt+(` wraps the selection (or whole line) in parentheses. Safe to call more than once.
Does nothing if PSReadLine isn't available, so a minimal host never throws out of startup.

```powershell
Initialize-PSReadline
```

### `Write-Figlet`

Renders text as figlet (large ASCII) art via PwshSpectreConsole. It powers the startup banner
(`Initialize-PwshProfile` calls it) but is a general-purpose writer — call it anywhere you
want big ASCII text. It writes only the figlet text (no trailing blank line); add your own
spacing if you want a gap after it. If PwshSpectreConsole isn't loaded, it renders nothing
rather than failing.

> **Renamed (breaking):** this was `Show-ProfileBanner`. There is no compatibility alias —
> update any `$PROFILE` that called `Show-ProfileBanner`. Beyond the name, `-Text` is now
> **required** (the old `$env:COMPUTERNAME` default is gone) and the trailing blank line the
> banner used to print is no longer emitted.

- **`-Text`** — text to render (**required**, position 0).
- **`-Color`** — any Spectre color name or hex (default `#c9aaff`, the bundled theme's purple).
- **`-Alignment`** — `Left`, `Center`, or `Right` (default `Left`).
- **`-Font`** — a bundled FIGlet font (default `ANSIShadow`; tab-completes). Mutually exclusive with `-FontPath`.
- **`-FontPath`** — path to your own `.flf` font file. Mutually exclusive with `-Font`.

The module bundles **25** verified-readable FIGlet fonts spanning sizes, so you can match the font
to the message length. Run `Show-FigletFont` to list them (or `-Preview` to see samples). A
representative selection:

| Category   | `-Font` values                                                                 |
| ---------- | ------------------------------------------------------------------------------ |
| Compact    | `Small`, `Mini`, `SmSlant`                                                     |
| Medium     | `Standard`, `Slant`, `Ogre`, `Shadow`, `Speed`, `Cybermedium`, `Graffiti`      |
| Large/bold | `ANSIShadow`, `Colossal`, `Doom`, `ANSIRegular`, `Banner3`, `Block`, `SubZero`, `Univers`, `StarWars`, `Epic`, `Nancyj` |
| Decorative | `Larry3D`, `Isometric1`, `3D-ASCII`, `Bloody`                                  |

```powershell
Write-Figlet 'Screw City'                                  # ANSIShadow, purple, Left (defaults)
Write-Figlet 'DEPLOY' -Font Doom -Color Green -Alignment Center
Write-Figlet 'A longer status message' -Font Small         # compact font fits long text
Write-Figlet 'Hi' -FontPath ~/.fonts/custom.flf            # your own .flf
```

### `Show-FigletFont`

Surfaces the bundled FIGlet fonts so you can pick one for `Write-Figlet -Font` (or
`Initialize-PwshProfile -BannerFont`). **By default it lists the font names**; pass `-Preview`
to render a labelled sample of each instead.

- **`-Font`** — one or more bundled fonts to act on (default: all; tab-completes).
- **`-Preview`** — render samples instead of listing names.
- **`-Text`** — preview only: the string to render in each sample (default: each font's own name).

```powershell
Show-FigletFont                                       # list every bundled font name
Show-FigletFont -Preview                              # render a sample of each
Show-FigletFont ANSIShadow, Colossal -Preview -Text 'Deploy'   # preview a subset, custom text
```

> Note: not every `.flf` in the wild loads under Spectre's FIGlet parser. The bundled fonts are
> verified to render; if a custom `-FontPath` fails to load, try a different file. (See
> `Assets/Fonts/README.md` for sources and license.)

### `Install-WindowsTerminalScheme`, `Uninstall-WindowsTerminalScheme`

Add (or remove) a **Windows Terminal color scheme** that matches a bundled prompt theme, so the
terminal's own 16-color ANSI palette, background, and cursor line up with the oh-my-posh prompt.
The scheme colors come from the same source of truth as the bat/fd/fzf colors
(`Get-BundledThemeBranding`), and the scheme is named after the theme's display name — **Screw
City** / **Forest City** — so it shows up under that name in Windows Terminal's
*Settings → Color schemes*.

`Install-WindowsTerminalScheme` writes the scheme into the user's `settings.json` `schemes` array
(idempotent — a re-run replaces the same-named scheme rather than duplicating it). By default it
only *registers* the scheme; pass `-SetDefault` to also set it as `profiles.defaults.colorScheme`
so it applies immediately. `Uninstall-WindowsTerminalScheme` removes the matching scheme.

- **`-Theme`** — the bundled theme whose scheme to install/remove (default `screwcity`;
  tab-completes; custom/unknown themes fall back to the Screw City scheme).
- **`-SettingsPath`** — override the `settings.json` location (default: the first existing of the
  stable, preview, and unpackaged Windows Terminal install paths).
- **`-SetDefault`** (install only) — also set the scheme as the default color scheme for all
  profiles.

Both back the original `settings.json` up to `settings.json.bak` before rewriting, and support
`-WhatIf` / `-Confirm`. If Windows Terminal isn't installed (no `settings.json` found), they warn
and change nothing.

> Note: `settings.json` is JSONC — the parse → rewrite round-trip does **not** preserve `//`
> comments or hand-formatting (the `.bak` backup is the safety net). Removing a scheme that's still
> referenced as an active `colorScheme` warns you to pick a replacement.

```powershell
Install-WindowsTerminalScheme                          # add the "Screw City" scheme to pick in WT
Install-WindowsTerminalScheme -Theme forestcity -SetDefault   # add "Forest City" and apply it now
Install-WindowsTerminalScheme -WhatIf                  # preview the change, write nothing
Uninstall-WindowsTerminalScheme -Theme forestcity      # remove the "Forest City" scheme
```

### `Enable-OhMyPosh`, `Enable-Zoxide`, `Enable-Fzf`, `Enable-FastNodeManager`, `Enable-Xh`, `Enable-Jq`, `Enable-Bat`, `Enable-Fd`, `Enable-Less`

Each installs a CLI tool with winget if it isn't already on PATH (patching the current
session's PATH so the install is usable immediately), then — for tools that need it — hooks
it into the session (install-only tools like `Enable-Jq` skip this). The
work is split into nested `Invoke-Step "Install"` / `Invoke-Step "Initialize"` substeps, so
the two phases show as breadcrumb stages under the spinner. winget's own output is captured
into a variable (`*>&1`) so it can't tear the live spinner. After install the exe is re-checked
with `Get-Command`; if it still isn't on PATH the captured output is surfaced via `Write-Warning`
and Initialize (also `Get-Command`-guarded) is skipped, so startup continues either way.

- **`Enable-OhMyPosh [-Configuration <path>]`** — installs `JanDeDobbeleer.OhMyPosh` (user
  scope) and runs `oh-my-posh init pwsh` with a theme via `--config`. Defaults to the module's
  bundled `Assets/Themes/screwcity.omp.json`; pass `-Configuration` to use a different theme.
- **`Enable-Zoxide [-Command <name>]`** — installs `ajeetdsouza.zoxide` and runs
  `zoxide init powershell --cmd <name> --hook none` (default `cd`, replacing the built-in). It tracks
  the directories you visit via a `LocationChangedAction` hook (running `zoxide add` on every change),
  **not** zoxide's default prompt wrapper — the prompt wrap is silently wiped when oh-my-posh removes
  and re-adds its prompt module on a profile reload, so directories would stop being recorded. The
  location hook is immune to that (it chains any existing handler and doesn't re-register on reload,
  composing with `Enable-FastNodeManager`'s hook).
- **`Enable-Fzf [-Colors <spec>] [-Style <preset>] [-Height <value>] [-PreviewCommand <cmd>]
  [-ProviderChord <chord>] [-HistoryChord <chord>] [-TabExpansionChord <chord>] [-UseFd] [-GitKeyBindings]`** — installs `junegunn.fzf` (the command-line
  fuzzy finder), themes it, and wires up its PowerShell key bindings. It composes
  `$env:FZF_DEFAULT_OPTS` (the baseline for *every* fzf invocation, always with `--ansi`) from
  `-Colors` (`--color`, the prompt blend) and `-Style` (`--style`, e.g. `full` — added only when the
  installed fzf is **0.54+**, since an older pre-existing fzf would reject the unknown option); it
  carries **no** `--preview`, so directory pickers stay clean. `-PreviewCommand` is
  written to `$env:FZF_CTRL_T_OPTS` instead — scoped to the **Ctrl+T file picker** (so the bat
  preview shows for file searches but never for directory pickers like zoxide's `cdi`). Because fzf
  ships **no** PowerShell key bindings, `-ProviderChord`/`-HistoryChord`/`-UseFd`/`-GitKeyBindings`
  install/import the **PSFzf** module and call `Set-PsFzfOption` to bind **Ctrl+T** (fd-sourced file
  picker with the bat preview) and **Ctrl+R** (fuzzy history, overriding native reverse-search), make
  PSFzf use fd for traversal (`-EnableFd`), and register the **Ctrl+G** fuzzy-git chords (only when
  git is on PATH). `-TabExpansionChord` binds a chord to PSFzf's `Invoke-FzfTabCompletion` (via
  `Set-PSReadLineKeyHandler`, since `Set-PsFzfOption -TabExpansion` only ever targets `Tab`), opening a
  fuzzy fzf picker over PowerShell's native completions — paths, command/parameter names, and every
  registered completer — while leaving `Tab` as the classic `MenuComplete`. After importing PSFzf it
  also patches PSFzf's internal `FixCompletionResult` (which otherwise double-quotes any candidate
  containing whitespace) to trim the trailing "complete" space many completers append, so external-CLI
  fuzzy completions (`gh`, `az`, `winget`, …) insert as `az account ` rather than `az "account "`.
  `-Height` sizes those PSFzf pickers via `$env:_PSFZF_FZF_DEFAULT_OPTS` (PSFzf's
  widget-only opts, read in preference to `$env:FZF_DEFAULT_OPTS`): without it PSFzf forces an inline
  `--height=40%`; `Initialize-PwshProfile` passes `~100%` so the pickers adapt — filling the shell for
  large result sets but shrinking to fit small ones — while
  `$env:FZF_DEFAULT_OPTS` stays height-free so a bare `fzf` keeps its alternate-screen fullscreen.
  `Initialize-PwshProfile` passes the theme blend, `full` style, `~100%` height, the bat preview
  (when bat is in play), `Ctrl+t`/`Ctrl+r`, `Ctrl+Spacebar` for fuzzy completion, `-UseFd` (when fd
  is in play), and `-GitKeyBindings`. fzf
  owns its own options here; the *"use fd as fzf's source"* wiring (`$env:FZF_DEFAULT_COMMAND`)
  lives in `Enable-Fd`. zoxide's interactive picker (`cdi` / `zi`) reuses
  fzf and inherits the `--color`/`--style` baseline.
- **`Enable-FastNodeManager`** — installs `Schniz.fnm`, applies `fnm env` (recursive version-file
  strategy) and completions, and registers a `LocationChangedAction` hook that fires on every
  directory change (`cd`, `z`/`cdi`, `Set-Location`, `Push-Location`, `..`, …). On each filesystem
  change it runs `fnm use --silent-if-unchanged` — fnm resolves the version recursively (reverting
  to the default version outside a Node project) and emits nothing unless the active version
  actually changes, so moving around a non-Node tree is silent (matching fnm's own `--use-on-cd`
  integration). It fires with or without zoxide and regardless of zoxide's jump command — chaining
  any existing `LocationChangedAction` (including zoxide's, which is registered the same way) and not
  re-registering on reload — so there's no ordering requirement relative to `Enable-Zoxide`.
- **`Enable-Xh`** — installs `ducaale.xh` (which ships `xh.exe` and `xhs.exe`), aliases
  `http`/`https` to them globally, and registers tab completion for all four names.
- **`Enable-Jq`** — installs `jqlang.jq` (the command-line JSON processor) and puts `jq.exe`
  on PATH. jq is a standalone C program with no built-in shell completion, so this is
  install-only — there's no Initialize work and no completion to register.
- **`Enable-Bat [-Theme <name>] [-Style <list>] [-ReplaceCat]`** — installs `sharkdp.bat`
  (a `cat` clone with syntax highlighting and git integration). In Initialize it sets
  `$env:BAT_THEME` to `-Theme` (so bat's colors match the prompt — `Initialize-PwshProfile`
  passes the active theme's blend: screwcity → `Dracula`, forestcity → `gruvbox-dark`) and
  `$env:BAT_STYLE` to `-Style` (default `numbers,changes,header`), registers bat's PowerShell
  completer (`bat --completion ps1`), and — with `-ReplaceCat` — aliases `cat` → `bat` globally
  and extends that completer to the `cat` alias so `cat <Tab>` completes bat's flags too
  (PowerShell completers don't follow aliases — the same trick `Enable-Xh` uses for `http`/`https`).
- **`Enable-Fd [-LsColors <spec>] [-IntegrateFzf]`** — installs `sharkdp.fd` (a fast, friendly
  `find` alternative that respects `.gitignore`). In Initialize it sets `$env:LS_COLORS` to
  `-LsColors` (so fd's output matches the prompt — `Initialize-PwshProfile` passes the active
  theme's truecolor blend), registers fd's PowerShell completer (`fd --gen-completions powershell`),
  and — with `-IntegrateFzf`, when `fzf.exe` is present — points a bare `fzf` at fd as its file
  source via `$env:FZF_DEFAULT_COMMAND` (the Ctrl+T picker uses PSFzf's own fd provider). **fd is
  standalone — it never aliases or replaces `Get-ChildItem`/`ls`.** (`LS_COLORS` is shared with
  `ls`/`eza`.) Enabled after `Enable-Fzf`
  so `fzf.exe` is on PATH when integration is evaluated.
- **`Enable-Less [-Options <string>] [-ReplaceMore]`** — installs `jftuga.less` (GNU less compiled
  standalone for Windows — a full-featured pager with color, search, and backward scroll, far beyond
  the built-in `more.com`). In Initialize it sets `$env:LESS` to `-Options` (default `-R -F -i`: raw
  color passthrough, quit-if-one-screen, smart-case search) and — with `-ReplaceMore` — sets
  `$env:PAGER` to `less` (so PowerShell's own `help`, `bat`, `git`, `delta`, and `gh` page through
  less rather than `more.com`) and aliases `more` → `less` globally. less is also what gives
  `Enable-Bat` color paging: bat's default pager is less, so without it on PATH bat can't page colored
  output. Unlike bat/fd, less ships no PowerShell completer and has no palette, so it registers no
  completion and isn't themed — `$env:LESS` carries functional defaults only.

```powershell
Enable-OhMyPosh -Configuration '~/OneDrive/.config/PoshThemes/craver.modified.omp.json'
Enable-Zoxide
Enable-Fzf -Colors 'hl:#5fd7ff,pointer:#c9aaff,prompt:#c9aaff' -Style full -Height '~100%' -PreviewCommand 'bat --color=always --style=numbers {}' -ProviderChord 'Ctrl+t' -HistoryChord 'Ctrl+r' -UseFd -GitKeyBindings
Enable-FastNodeManager
Enable-Xh
Enable-Jq
Enable-Bat -Theme Dracula -ReplaceCat
Enable-Fd -LsColors 'di=1;38;2;201;170;255:ln=38;2;95;215;255' -IntegrateFzf
Enable-Less -ReplaceMore
```

### `Get-OhMyPoshTheme`, `Export-OhMyPoshTheme`

Get a starting copy of a bundled oh-my-posh theme so you can customize it. Both take `-Theme`
(`screwcity` default, or `forestcity`; tab-completes) and read `Assets/Themes/<Theme>.omp.json`;
neither exposes that in-module path as an edit target — when the module is installed from a
repository it lives in a versioned, possibly read-only directory, so edits there would be lost on the
next update. Customize a copy *you* own and point `Enable-OhMyPosh -Configuration` (or
`Initialize-PwshProfile -CustomTheme`) at it.

- **`Get-OhMyPoshTheme [-Theme <name>]`** — emits the bundled theme's raw JSON to the pipeline
  (prints at a prompt; pipe to `clip`, a file, or an editor). Throws if the bundled theme is missing.
- **`Export-OhMyPoshTheme -Path <dest> [-Theme <name>] [-Force]`** — copies the bundled theme to
  `<dest>`. The path is required (console output is `Get-OhMyPoshTheme`'s job); an existing file is
  left untouched unless `-Force` is given. Supports `-WhatIf`/`-Confirm`.

```powershell
Get-OhMyPoshTheme | Set-Content ~/my.omp.json   # or: Export-OhMyPoshTheme -Path ~/my.omp.json
# edit ~/my.omp.json, then:
Enable-OhMyPosh -Configuration ~/my.omp.json
```

### `Enable-WingetCompletion`, `Enable-AzureCliCompletion`, `Enable-TailscaleCompletion`, `Enable-DockerCompletion`, `Enable-1PasswordCompletion`, `Enable-GithubCliCompletion`

One `Enable-<Tool>Completion` per CLI, used by the **Completions** sub-step under **Core** (and
living together under `Public/Tools/Completions/`). Each only registers tab completion (no install
phase), guards on its tool so a missing CLI is skipped silently, and opens no `Invoke-Step` of its
own — the caller supplies the step label — so they read as thin one-liners under the orchestrator.

- **`Enable-WingetCompletion`** — registers a native argument completer for `winget` that
  delegates to `winget complete`, so completion tracks the installed winget version. winget is
  assumed present (it installs every other tool), so there's no install step.
- **`Enable-AzureCliCompletion`** — registers a native argument completer for the Azure CLI (`az`). `az`
  is a Python (argcomplete) CLI with no `completion powershell` subcommand, so it drives argcomplete
  via a temp file and the `_ARGCOMPLETE` / `COMP_*` environment variables (the [supported mechanism](https://learn.microsoft.com/cli/azure/use-azure-cli-successfully-powershell#enable-tab-completion-in-powershell)).
  `Initialize-PSReadline` binds `Tab` to menu completion so the candidates render as a navigable list.
- **`Enable-TailscaleCompletion`** / **`Enable-1PasswordCompletion`** / **`Enable-GithubCliCompletion`** —
  register completion for the Cobra-based `tailscale` / `op` (1Password) / `gh` (GitHub) CLIs. All
  wrap the module-private `Register-CobraCompletion` engine, which generates `<Command> completion
  powershell` and activates it via `Invoke-InGlobalScope` (run in global scope so its helpers stay
  reachable at tab time without being tagged to the module). `tailscale` / `op` take the shell
  positionally; `gh` is the exception — it requires `completion -s powershell` (a bare positional
  `powershell` makes gh emit bash), so `Enable-GithubCliCompletion` overrides the engine's default
  generation args via `Register-CobraCompletion`'s `-CompletionArgument` parameter.
- **`Enable-DockerCompletion`** — Docker has no built-in PowerShell completion subcommand; its
  completion ships as the community `DockerCompletion` module, which this imports via
  `Import-ModuleSafe`. Guarded by `Get-Command docker`, so the module is never fetched from the
  gallery on a machine without Docker.

```powershell
Enable-WingetCompletion
Enable-AzureCliCompletion
Enable-TailscaleCompletion
Enable-DockerCompletion
Enable-1PasswordCompletion
Enable-GithubCliCompletion
```

### `Set-WingetSetting`

Merges a curated set of [winget](https://learn.microsoft.com/windows/package-manager/winget/)
client preferences into winget's user settings. It reads the current settings, sets only the keys
you pass, and writes the full object back, so unrelated settings — and the `$schema` key that drives
editor IntelliSense — are preserved. This is what the install wizard's **Winget** step calls when
you submit, but it's also useful on its own.

The read and write go through Microsoft's first-party
[`Microsoft.WinGet.Client`](https://www.powershellgallery.com/packages/Microsoft.WinGet.Client/)
module (`Get-WinGetUserSetting` / `Set-WinGetUserSetting`), loaded on demand via `Import-ModuleSafe`
(installed CurrentUser if absent) — so it's not a startup dependency. Like the rest of the module
it's failure-tolerant: if the module can't load or the write fails it warns rather than throwing.

- **`-Scope`** — default install scope, written to `installBehavior.preferences.scope`: `user` or
  `machine`. `user` *prefers* a per-user installer (no admin prompt) and falls back to machine when
  a package offers none — it never hard-requires user scope, so installs don't fail.
- **`-ProgressBar`** — `visual.progressBar` style: `accent`, `rainbow`, `retro`, `sixel`, or
  `disabled`.
- **`-AnonymizePath`** — `[bool]` for `visual.anonymizeDisplayedPaths`; replaces known folders with
  their environment-variable names (e.g. `%LOCALAPPDATA%`) in winget output.
- **`-DisableInstallNote`** — `[bool]` for `installBehavior.disableInstallNotes`; suppresses the
  notes some packages print after a successful install.

Supports `-WhatIf` / `-Confirm`.

```powershell
Set-WingetSetting -Scope user -ProgressBar rainbow -AnonymizePath $true -DisableInstallNote $false
Set-WingetSetting -Scope machine -WhatIf        # preview only the scope change
```

### `Select-Fzf`

A general-purpose [fzf](https://github.com/junegunn/fzf) wrapper for interactive fuzzy selection over
**objects** from the pipeline. It replaces hand-rolled one-off pipelines — e.g.
`Get-AzSubscription | % { "{0}`t{1}" -f $_.Name, $_.Id } | fzf --with-nth 1 --nth 1 --accept-nth 2 --delimiter "`t"`
— with a single command that hands back the **live selected object(s)**, not text you have to
re-parse. Pipe in any objects, say what to display and (optionally) what to return.

Internally each item is tagged with a hidden integer index and rendered as an `<index><US><display>`
line, joined by ASCII Unit Separator (`0x1f`) — a non-printable control char that can't collide with
human-readable display text, so the display keeps its tabs/colons (only newlines are collapsed). fzf
runs with `--delimiter` / `--with-nth=2..` so the index column is hidden and `--with-nth` scopes both
the display **and the fuzzy search** to the text column (no `--nth` — it would re-index the
post-`--with-nth` view and break matching), then the selected line's leading index maps back to the
original object. It's invoked with `--ansi` and
inherits `$env:FZF_DEFAULT_OPTS`, so when [`Enable-Fzf`](#enable-ohmyposh-enable-zoxide-enable-fzf-enable-fastnodemanager-enable-xh-enable-jq-enable-bat-enable-fd-enable-less) has themed fzf the
picker matches your prompt palette automatically. Requires `fzf` on PATH (it warns and returns nothing
otherwise); an empty pipeline or an Esc cancel also returns nothing — it never throws.

- **`-Display`** — what to show per item: a property **name** (string) or a **scriptblock** (`$_` is
  the item), e.g. `{ "{0} ({1})" -f $_.Name, $_.Id }`. Omit it to use the item's string form. This is
  the only text shown and the only text fzf searches.
- **`-Value`** — what to return: a property name or scriptblock. Omit it to return the **whole
  object** (the default — `.Property` still works on the result).
- **`-Multiple`** — enable multi-select (`--multi`, Tab to mark rows); returns an array.
- **`-Prompt` / `-Header`** — fzf's `--prompt` / `--header`. (There's no `-Preview` parameter: a
  preview would only see the rendered row text, not the live object — pass `-FzfArgument '--preview=…'`
  if you want raw-text preview anyway.)
- **`-Height`** — fzf's `--height`, default `~100%` (adaptive). Set `''` for fzf's own default.
- **`-FzfArgument`** — escape hatch: extra raw fzf args appended verbatim (e.g. `--cycle`, `--border`).

```powershell
Get-ChildItem | Select-Fzf -Display Name                      # returns the selected FileInfo/DirectoryInfo
Get-AzSubscription | Select-Fzf -Display Name -Value Id        # show names, return the chosen Id
Get-Process | Select-Fzf -Display { "{0} ({1})" -f $_.Name, $_.Id } -Multiple -Prompt 'kill> '
```

### `Show-PwshProfileReadme`

Renders this README straight from the installed module so the docs are one command away from any
session. By default it prints to the console via `Show-Markdown`; pass `-Open` to hand `README.md`
to the application registered for `.md` files instead (via `Invoke-Item`). Throws if the bundled
README can't be found.

- **`-Open`** — open the README in your default Markdown application instead of rendering it in the
  console.

```powershell
Show-PwshProfileReadme          # render in the console with Show-Markdown
Show-PwshProfileReadme -Open    # open README.md in the default Markdown app
```

## Development

To hack on the module, clone the repo and import the manifest directly — re-run with `-Force`
after each change to reload your working copy:

```powershell
Import-Module ./ScrewCitySoftware.PwshProfile.psd1 -Force
```

Adding a function is the three touches described under [Layout](#layout) (a new `Public/<area>/`
file, its name in `FunctionsToExport`, and a README section); a module-level test enforces that
those stay in sync and that every function carries comment-based help.

For console-rendering changes (`Invoke-Step`, `Write-Figlet`), eyeball the result in a fresh
`pwsh -NoProfile` session with the module imported — the Spectre spinner only renders in an
interactive console, so the tests mock it rather than see it:

```powershell
pwsh -NoProfile
Import-Module ./ScrewCitySoftware.PwshProfile.psd1
Invoke-Step "Demo" { Start-Sleep -Milliseconds 50 }
```

### Tests

The `Tests/` folder holds Pester 5 tests: module-level checks (valid manifest, exports match
the manifest, every function documented) plus per-function behavior tests across the module —
`Invoke-Step` rendering, `Import-ModuleSafe` install/import/failure paths, the profile
install/uninstall/wizard logic, and the rest. Install Pester with `Install-PSResource Pester`
if it's missing.

```powershell
Invoke-Pester -Path ./Tests
```

That's the quick inner loop, but it skips PSScriptAnalyzer and does **not** set
`Set-StrictMode -Version Latest` — so it can hide failures CI catches (e.g. reads of unset
variables, lint findings). Before pushing, run the checks the way CI does — in a **clean**
PowerShell session (no profile loaded, so the module's own global state can't mask a failure):

```powershell
pwsh -NoProfile -NoLogo -Command "& .\build.ps1 -Task Analyze, Test"
```

See [Build & release](#build--release) for the full task list.

### Build & release

[`build.ps1`](build.ps1) is a dependency-free task runner — each `-Task` maps to a function and
they run in order. The default chain lints, tests, and stages a shippable copy of the module:

Run it in a **clean** PowerShell session (`-NoProfile`) so a profile-loaded module / global state
can't mask or alter results — that's what CI does:

```powershell
pwsh -NoProfile -NoLogo -Command "& .\build.ps1"                      # Bootstrap -> Analyze -> Test -> Build
pwsh -NoProfile -NoLogo -Command "& .\build.ps1 -Task Analyze, Test"  # what CI runs on pull requests
```

`Build` stages **only** the shippable files (`.psd1`, `.psm1`, `Public/`, `Private/`, `Assets/`,
`README.md`, `LICENSE`) into `Output/ScrewCitySoftware.PwshProfile/`, so `Tests/`, `CLAUDE.md`,
and `.github/` never reach the gallery package.

CI runs lint + tests on every push and pull request
([`.github/workflows/ci.yml`](.github/workflows/ci.yml)). Publishing to the PowerShell Gallery is
automated on release ([`.github/workflows/publish.yml`](.github/workflows/publish.yml)). To cut a
release:

1. Bump `ModuleVersion` in the manifest (and set `Prerelease` for a preview, e.g. `preview1`).
2. Push, then create a GitHub release tagged `vX.Y.Z` (or `vX.Y.Z-preview1`) with notes describing
   the changes — the [Releases page](https://github.com/screwcitysoftware/PwshProfile/releases) is
   the changelog. The workflow guards that the tag and manifest version agree, then builds and runs
   `Publish-PSResource`.

The publish workflow reads the gallery API key from the `PSGALLERY_API_KEY` repository secret.

## License

This project's code and original assets (including the `screwcity.omp.json` and
`forestcity.omp.json` oh-my-posh themes) are released under the MIT License — see
[`LICENSE`](LICENSE).

Two carve-outs:

- **Bundled FIGlet fonts** (`Assets/Fonts/*.flf`) are not original to this project and are *not*
  covered by the MIT grant above. They remain under the permissive
  [FIGlet font license](http://www.figlet.org/), with each font's original author/credit line
  preserved inside its `.flf` header. See [`Assets/Fonts/README.md`](Assets/Fonts/README.md) for
  sources and attribution.
- **Third-party CLI tools and modules** (oh-my-posh, zoxide, fzf, fnm, xh, jq, bat, fd, less,
  PwshSpectreConsole,
  Terminal-Icons, posh-git, PSFzf, the Cobra-based CLIs, and the first-party `Microsoft.WinGet.Client`
  module used for package installs and winget user-setting changes) are *invoked* at runtime, never
  bundled or redistributed here, and remain under their own respective licenses.
