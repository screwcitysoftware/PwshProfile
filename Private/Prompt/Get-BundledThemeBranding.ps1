function Get-BundledThemeBranding {
    <#
    .SYNOPSIS
        Returns the display name, banner color, step icon, bat theme, fd/fzf color specs, and Windows
        Terminal color scheme paired with a bundled theme.

    .DESCRIPTION
        Each bundled theme has a matching identity so the startup banner, step marker, and the
        colors of bat, fd, and fzf feel cohesive with the prompt colors:

          screwcity  -> 'Screw City'  / banner #4c81c8 (signature purple #c9aaff stays in the palettes)
                                       / :nut_and_bolt:   (🔩) / Dracula
          forestcity -> 'Forest City' / banner #8fce72 (also the signature green)
                                       / :deciduous_tree: (🌳) / gruvbox-dark

        DisplayName is the theme's friendly label (shown in the install wizard's theme picker); it is
        NOT the banner text — the default banner text is uniformly $env:COMPUTERNAME for every theme
        (see Get-PwshProfileDefault / Initialize-PwshProfile). The step icon is stored without a
        trailing space; the separator between the glyph and the step text is added at render time
        (Get-StepIconPrefix). BatTheme is the `bat --list-themes` value Enable-Bat assigns to
        $env:BAT_THEME so bat's highlighting matches the prompt palette.

        LsColors is an LS_COLORS spec Enable-Fd assigns to $env:LS_COLORS so fd's output is tinted to
        match the prompt; it uses truecolor (38;2;R;G;B) matching the signature hex exactly. FzfColors
        is an fzf `--color` spec Enable-Fzf folds into $env:FZF_DEFAULT_OPTS so fzf's picker matches
        the prompt (also truecolor hex). Both are fixed RGB, so they render identically across
        terminals rather than following the terminal's own scheme.

        TerminalScheme is a Windows Terminal color scheme (a hashtable in the shape Windows Terminal's
        settings.json `schemes` array expects: `name`, `background`, `foreground`, `cursorColor`,
        `selectionBackground`, and the 16 ANSI keys black..white + bright*). Install-WindowsTerminalScheme
        writes it into the user's settings.json so the terminal's own palette matches the prompt. Its
        `name` is the DisplayName, so it reads nicely in Windows Terminal's color-scheme dropdown. Like
        LsColors/FzfColors the hex values are hardcoded here (not parsed out of the theme's .omp.json),
        keeping this map the single source of truth for the theme's color identity.

        Both Initialize-PwshProfile (at startup, to fill the banner color/icon not explicitly passed)
        and Get-PwshProfileDefault (at install time, to pre-fill the wizard and seed the comparison
        baseline) resolve color/icon through here, so the two stay in sync from one source.

        Any unrecognized name — including a custom theme path chosen at install — falls back to the
        'screwcity' branding, which is the module's neutral default identity.

    .PARAMETER Name
        The bundled theme name (e.g. 'screwcity', 'forestcity'). Unknown names fall back to
        'screwcity'.

    .EXAMPLE
        Get-BundledThemeBranding -Name forestcity

        Returns @{ DisplayName = 'Forest City'; BannerColor = '#8fce72'; StepIcon = ':deciduous_tree:';
        BatTheme = 'gruvbox-dark'; LsColors = '…'; FzfColors = '…'; TerminalScheme = @{ … } }.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Name = 'screwcity'
    )

    $branding = @{
        screwcity  = @{
            DisplayName = 'Screw City'
            BannerColor = '#4c81c8'
            StepIcon    = ':nut_and_bolt:'
            BatTheme    = 'Dracula'
            # Purple dirs / cyan symlinks / green executables / amber archives / magenta images.
            LsColors    = 'di=1;38;2;201;170;255:ln=38;2;95;215;255:ex=1;38;2;143;206;114:*.zip=38;2;255;175;95:*.tar=38;2;255;175;95:*.gz=38;2;255;175;95:*.7z=38;2;255;175;95:*.png=38;2;215;135;255:*.jpg=38;2;215;135;255:*.jpeg=38;2;215;135;255:*.gif=38;2;215;135;255:*.svg=38;2;215;135;255'
            FzfColors   = 'fg:-1,bg:-1,hl:#5fd7ff,fg+:#ffffff,bg+:#3a3a3a,hl+:#c9aaff,info:#c9aaff,prompt:#c9aaff,pointer:#c9aaff,marker:#8fce72,spinner:#5fd7ff,header:#5fd7ff'
            # Maps the shared palette keys (purple-deep bg, gray-light fg, signature purple-light
            # cursor/brightPurple, violet-mid selection, *-bright/*-light pairs for the ANSI 8+8).
            TerminalScheme = @{
                name                = 'Screw City'
                background          = '#1a1033'
                foreground          = '#c4c4c4'
                cursorColor         = '#c9aaff'
                selectionBackground = '#4a3585'
                black               = '#1a1a1a'
                red                 = '#e05e5e'
                green               = '#43c97e'
                yellow              = '#ffb347'
                blue                = '#5ba4d4'
                purple              = '#9f7be7'
                cyan                = '#2496ed'
                white               = '#c4c4c4'
                brightBlack         = '#8a8a8a'
                brightRed           = '#f09090'
                brightGreen         = '#7de0aa'
                brightYellow        = '#ffd080'
                brightBlue          = '#7bb3f0'
                brightPurple        = '#c9aaff'
                brightCyan          = '#60b8f5'
                brightWhite         = '#ffffff'
            }
        }
        forestcity = @{
            DisplayName = 'Forest City'
            BannerColor = '#8fce72'
            StepIcon    = ':deciduous_tree:'
            BatTheme    = 'gruvbox-dark'
            # Green dirs / teal symlinks / gold executables / brown archives / light-green images.
            LsColors    = 'di=1;38;2;143;206;114:ln=38;2;102;217;197:ex=1;38;2;229;192;123:*.zip=38;2;191;143;94:*.tar=38;2;191;143;94:*.gz=38;2;191;143;94:*.7z=38;2;191;143;94:*.png=38;2;152;195;121:*.jpg=38;2;152;195;121:*.jpeg=38;2;152;195;121:*.gif=38;2;152;195;121:*.svg=38;2;152;195;121'
            FzfColors   = 'fg:-1,bg:-1,hl:#66d9c5,fg+:#ffffff,bg+:#3a3a3a,hl+:#8fce72,info:#8fce72,prompt:#8fce72,pointer:#8fce72,marker:#e5c07b,spinner:#66d9c5,header:#66d9c5'
            # Same palette-key mapping as screwcity, recolored to the forest palette.
            TerminalScheme = @{
                name                = 'Forest City'
                background          = '#102a18'
                foreground          = '#ccc6b9'
                cursorColor         = '#8fce72'
                selectionBackground = '#3a5a3d'
                black               = '#1b1a17'
                red                 = '#d65f43'
                green               = '#6fc14b'
                yellow              = '#c89b5a'
                blue                = '#6fa6a0'
                purple              = '#9bbf8a'
                cyan                = '#4fb0a0'
                white               = '#ccc6b9'
                brightBlack         = '#9a9387'
                brightRed           = '#f0937c'
                brightGreen         = '#9fe07d'
                brightYellow        = '#e0c79a'
                brightBlue          = '#9cc6bf'
                brightPurple        = '#8fce72'
                brightCyan          = '#84cdc0'
                brightWhite         = '#ffffff'
            }
        }
    }

    if ($branding.ContainsKey($Name)) { $branding[$Name].Clone() } else { $branding['screwcity'].Clone() }
}
