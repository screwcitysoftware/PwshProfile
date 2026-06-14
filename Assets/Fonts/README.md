# Bundled FIGlet fonts

These `.flf` files are classic [FIGlet](http://www.figlet.org/) fonts, bundled so
`Write-Figlet -Font <name>` and `Initialize-PwshProfile -BannerFont <name>` work out of
the box. The file base name **is** the `-Font` value. Run `Show-FigletFont` to list them or
`Show-FigletFont -Preview` to see samples; the accepted `-Font` set is discovered dynamically
from this folder (see `Private/Rendering/Get-BundledFontName.ps1`), so adding or removing a `.flf` here
changes the available fonts with no code changes.

`ANSIShadow` is the default font for `Write-Figlet` / the startup banner.

| Font          | Rows | Category   | Notes                                          |
| ------------- | ---- | ---------- | ---------------------------------------------- |
| `Mini`        | 4    | Compact    | Tiny — best for long messages                  |
| `Small`       | 5    | Compact    | Compact general-purpose                        |
| `SmSlant`     | 5    | Compact    | Compact slanted                                |
| `Cybermedium` | 4    | Medium     | Clean, condensed                               |
| `Shadow`      | 5    | Medium     | Light drop-shadow                              |
| `Slant`       | 6    | Medium     | Italic, stylish                                |
| `Standard`    | 6    | Medium     | The all-purpose classic                        |
| `Speed`       | 6    | Medium     | Fast, slanted                                  |
| `Ogre`        | 6    | Medium     | Rounded, very readable                         |
| `Graffiti`    | 6    | Medium     | The classic figlet default look                |
| `ANSIRegular` | 7    | Large      | Solid box blocks (companion to ANSIShadow)     |
| `ANSIShadow`  | 7    | Large      | Bold box blocks with shadow — **default**      |
| `Banner3`     | 7    | Large      | Big solid `#` letters                          |
| `StarWars`    | 7    | Large      | Iconic crawl style                             |
| `SubZero`     | 6    | Large      | Heavy block letters                            |
| `Block`       | 8    | Large      | Wide outline blocks                            |
| `Doom`        | 8    | Large      | Clean, bold                                    |
| `Epic`        | 9    | Large      | Tall, imposing                                 |
| `Nancyj`      | 9    | Large      | Bold, rounded — very readable                  |
| `Colossal`    | 11   | Large      | Classic 3-D block letters                      |
| `Univers`     | 11   | Large      | Tall solid blocks                              |
| `Larry3D`     | 9    | Decorative | 3-D outline                                    |
| `Bloody`      | 10   | Decorative | Dripping horror style                          |
| `3D-ASCII`    | 10   | Decorative | Layered 3-D                                    |
| `Isometric1`  | 11   | Decorative | Isometric 3-D cubes                            |

## Source & license

Retrieved from the [`xero/figlet-fonts`](https://github.com/xero/figlet-fonts) mirror of the
official FIGlet font collection. The classic fonts (Standard, Small, Slant, etc.) are by
Glenn Chappell & Ian Chai; the rest are part of the standard contributed FIGlet font collection.
All are distributed under the [FIGlet font license](http://www.figlet.org/) and are freely
redistributable; the original author/credit lines are preserved inside each `.flf` file's header
comment block. Upstream files with spaces in their names were renamed to remove the spaces (e.g.
`ANSI Regular.flf` → `ANSIRegular.flf`, `Star Wars.flf` → `StarWars.flf`, `Sub-Zero.flf` →
`SubZero.flf`, `Small Slant.flf` → `SmSlant.flf`).

> Note: not every `.flf` in the wild works under PwshSpectreConsole's Spectre.Console FIGlet
> parser — some throw on load (`Big.flf`: "Unknown index for FIGlet character"; `Digital`,
> `Georgia11`), and some load but render **blank** (`Roman`). All were excluded. Every font bundled
> here is verified to produce real output. If you supply your own via `-FontPath` and it fails to
> load or renders empty, try a different `.flf`.
