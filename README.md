# dotctl

Unified theme controller for a Hyprland Wayland desktop. One command
re-themes cava, kitty, mako, wofi, waybar, hyprland, and hyprpaper against
a coordinated state file - no more editing seven config files to change a
color.

```sh
dotctl set -c forest -f meslo      # all five UI elements switch together
dotctl set --font-size 22          # scale every font for a 4K display
dotctl set --waybar-color gruvbox  # drift just waybar off the shared theme
dotctl cycle wallpaper next        # keybind entry point
```

---

## What it manages

| Element       | Color | Font | Size | Extras                                                        |
|---------------|:-----:|:----:|:----:|---------------------------------------------------------------|
| **cava**      |   ✓   |      |      |                                                               |
| **kitty**     |   ✓   |  ✓   |  ✓   |                                                               |
| **mako**      |   ✓   |  ✓   |  ✓   |                                                               |
| **wofi**      |   ✓   |  ✓   |  ✓   | subvariant (1/2)                                              |
| **waybar**    |   ✓   |  ✓   |  ✓   | style, scope, decor, vpn, transparent, opacity, launcher logo |
| **hypr**      |   ✓   |      |      | window effect (shadow/glow)                                   |
| **wallpaper** |   ✓   |      |      | cycle script per theme                                        |

Everything lives in one 23-field, hand-editable state file at
`~/.config/dotctl/config`. `dotctl configure` walks a wizard through every
axis; `dotctl set` takes targeted flags; `dotctl apply` re-reads the file
after a hand edit; `dotctl watch` auto-applies on save.

## Features

- **Unified switch** - `dotctl set -c <color> -f <font>` fans out across
  cava, kitty, mako, wofi, and waybar in one command.
- **Per-element override** - still want gruvbox on waybar while the rest
  stays forest? `dotctl set --waybar-color gruvbox`.
- **`sync`** - copy color/font from one element to another, or to `all`,
  to re-unify after drift.
- **Presets** - `dotctl preset save tv` / `dotctl preset load laptop`
  for named display setups.
- **Cycle keybinds** - `SUPER+ALT+Arrow` rotates wallpapers within the
  current theme or waybar variants within the current palette.
- **Waybar palette injection** - a single canonical `config.jsonc` /
  `style.css` pair per variant, with palette, font, and decorator glyphs
  rewritten at apply time. Add a new palette by dropping a `.palette`
  file in place.
- **Wallpaper themes as directories** - drop a folder of images, run
  `dotctl scan`, get a cycle script back. Curate `IMAGES=( )` by hand for
  a non-alphabetical order.
- **Hyprland integration without editing `hyprland.conf`** - ships two
  sourceable snippets (`dotctl-keybinds.conf` + `dotctl-colors.conf`)
  that you enable with two one-liners.
- **Transparent or opaque waybar** - toggle plus explicit opacity when
  you want the bar to sit at 30% over the wallpaper.
- **Launcher distro logo** - pick from 14 distro glyphs; the choice
  survives `cycle waybar` rotations.
- **Drift detection** - `dotctl show` flags any element whose color or
  font has drifted off the rest of the UI.

## Included content

**Colors** (5): `coyote`, `decay_green`, `forest`, `gruvbox`, `tokyo_night`
**Fonts** (2): `meslo`, `phoenix`
**Waybar variants** (4): `pill_full`, `pill_minimal`, `console_full`, `console_minimal`
**Waybar decorators** (console-only): `pointed`, `round`
**Launcher logos** (14): `tux`, `arch`, `gentoo`, `debian`, `void`, `nixos`, `fedora`, `fedora_inverse`, `endeavouros`, `cachyos`, `opensuse`, `artix`, `slackware`, `slackware_inverse`
**Wallpaper themes** (11): `arch`, `coyote`, `forest`, `gentoo`, `gruvbox`, `nixos`, `ocean`, `opensuse`, `slackware`, `tokyo_night`, `void`

## Requirements

**Hard requirements** (the installer aborts without them):
- `hyprland`
- `hyprpaper`

**Runtime elements** (install.sh offers to package-manage these for you):
- `waybar`, `cava`, `kitty`, `mako`, `wofi`
- `inotify-tools` (optional - powers `dotctl watch`; 1 s mtime polling fallback if missing)
- `jq`, `wl-clipboard`

**Known-good distros** (auto-detected by `install.sh`):
Gentoo, Arch / CachyOS / EndeavourOS / Manjaro / Artix, Debian / Ubuntu /
Mint / Pop!\_OS, Fedora / Nobara, openSUSE, Void, NixOS, Slackware. Other
distros work - you just get a "please install these manually" notice.

**Fonts**: the shipped palettes assume a Nerd Font is available
(`MesloLGS NF` or `Phoenix Sans`). Install one via your package manager
or drop the TTFs into `~/.local/share/fonts/` and run `fc-cache -f`.

## Install

```sh
git clone https://github.com/<your-fork>/dotctl.git
cd dotctl
./install.sh
```

The installer is interactive and walks you through:

1. Verify `hyprland` + `hyprpaper` are present (hard fail otherwise).
2. Optionally `pacman -S` / `emerge` / etc. the runtime elements.
3. Symlink the CLI + module scripts (`dotctl`, `power`, `launcher`,
   `cputemp`, `gputemp`, `audio-output`, `audio-output-menu`,
   `audio-hotplug-watch`) into `/usr/local/bin/`.
4. Optionally symlink the VPN module (`vpnctl`, `vpn-status-indicator`).
5. Copy themed configs into `~/.config/{cava,kitty,mako,wofi,waybar}`.
6. Copy wallpaper cycle scripts + template into `~/.config/dotctl/cycle/`.
7. Drop the hyprland snippets into `~/.config/hypr/`.
8. Install the man page to `/usr/local/share/man/man1/dotctl.1.gz`.
9. Optionally copy wallpaper packs into `~/Pictures/dotctl/wallpapers/`.

Steps 3, 4, 8 use `sudo` (one prompt at the top; the rest runs as you).
Nothing in `install.sh` touches `hyprland.conf` itself - the post-install
block tells you exactly which two `source =` lines to add by hand.

### Hyprland wiring

Add these to the **bottom** of `~/.config/hypr/hyprland.conf` (later
sources override earlier ones):

```ini
source = ~/.config/hypr/dotctl-keybinds.conf
source = ~/.config/hypr/dotctl-colors.conf
```

Then `hyprctl reload`. You now have:

- `SUPER+ALT+Right` / `Left` - cycle wallpaper within the current theme
- `SUPER+ALT+Up` / `Down` - rotate waybar variants (pill/console × full/minimal)
- `ALT+SHIFT+A` - route audio to analog / line-out
- `ALT+SHIFT+S` - route audio to headset / bluetooth
- `ALT+SHIFT+H` - route audio to HDMI / DisplayPort
- `ALT+SHIFT+M` - toggle mute on the default sink

## Quick start

First-time setup walks every axis:

```sh
dotctl configure
```

Everyday commands:

```sh
dotctl show                                # current state + drift warnings
dotctl set -c tokyo_night -f phoenix       # unified theme switch
dotctl set --font-size 22                  # scale every font
dotctl set --kitty-font-size 14            # shrink only kitty
dotctl set --waybar-color gruvbox          # drift waybar off the shared theme
dotctl sync all kitty                      # re-unify: all take kitty's color+font
dotctl set --waybar-style console --waybar-decor round
dotctl set --waybar-transparent off --waybar-opacity 0.60
dotctl set --waybar-vpn on                 # needs vpnctl + vpn-status-indicator
dotctl set --hypr-effect glow              # colored glow instead of drop shadow
dotctl set --launcher-logo nixos           # survives cycle waybar rotations
dotctl set -w gentoo                       # wallpaper-only, UI untouched
```

Presets:

```sh
dotctl preset save laptop
dotctl preset load tv
dotctl preset list
```

Every command accepts `-h` / `--help`:

```sh
dotctl set --help
dotctl cycle --help
dotctl list help
```

Full reference: `man dotctl`.

## Concepts

### Elements vs. sources vs. active files

dotctl never edits the themed source directories. Each apply reads the
current state, copies or palette-injects the selected theme into a
single "active" file each app reads, and signals the daemon:

| Element   | Source dir                                           | Active file                         | Reload signal            |
|-----------|------------------------------------------------------|-------------------------------------|--------------------------|
| cava      | `~/.config/cava/<color>/config`                      | `~/.config/cava/config`             | (user restart)           |
| kitty     | `~/.config/kitty/<color>_<font>/kitty.conf`          | `~/.config/kitty/kitty.conf`        | (live-reload)            |
| mako      | `~/.config/mako/<color>_<font>/config`               | `~/.config/mako/config`             | `makoctl reload`         |
| wofi      | `~/.config/wofi/<color>_<font>/<variant>/style.css`  | `~/.config/wofi/style.css`          | (on next launch)         |
| waybar    | `~/.config/waybar/<style>_<scope>/{config.jsonc,style.css}` + `palettes/<color>.palette` + `fonts/<font>.fontdef` + `decorators/<decor>.glyphs` | `~/.config/waybar/{config.jsonc,style.css}` | `pkill -SIGUSR2 waybar` |
| hypr      | `~/.local/share/dotctl/dotctl-colors.conf.tmpl` + active waybar palette | `~/.config/hypr/dotctl-colors.conf` | `hyprctl reload`         |
| wallpaper | `~/Pictures/dotctl/wallpapers/<theme>/` + `~/.config/dotctl/cycle/cycle-hyprpaper-<theme>` | `hyprpaper` daemon                  | (hyprpaper reload)       |

Font sizes are rewritten by `sed` against the active copy only; themed
sources stay canonical. The waybar config.jsonc and style.css are
**palette-injected**: the `@define-color` block is rewritten from the
active `.palette` file on every apply, so a single canonical pair of
variant files drives all 5 × 4 = 20 color/variant combinations.

### State file

`~/.config/dotctl/config` is 23 `KEY=value` lines, flock-guarded on
writes. You can hand-edit it and re-apply with `dotctl apply`, or run
`dotctl watch` in a second terminal to auto-apply on save:

```sh
CAVA_COLOR=forest
KITTY_COLOR=forest
KITTY_FONT=meslo
KITTY_FONT_SIZE=11
...
WAYBAR_STYLE=console
WAYBAR_SCOPE=full
WAYBAR_DECOR=round
WAYBAR_VPN=on
WAYBAR_TRANSPARENT=on
WAYBAR_OPACITY=0.30
WAYBAR_LAUNCHER_LOGO=gentoo
HYPR_EFFECT=glow
WALLPAPER=forest
```

Older state files at `~/.cache/dotctl/state` are auto-migrated on first
run. New fields added in a dotctl update are soft-migrated to defaults.

### Axes vs. flag precedence

`dotctl set` has three flag tiers with strict precedence:

1. `--preset <name>` - load a saved state as the baseline
2. `-c / -f / --font-size` - fan out across every element that has the axis
3. `--<element>-<axis>` - per-element override on top of the above

So `dotctl set --preset laptop -c forest --waybar-color gruvbox` loads
the laptop preset, forces forest on cava/kitty/mako/wofi/waybar, then
drifts waybar alone to gruvbox.

## Adding your own content

### New color

Drop matching directories at every element location:

```
~/.config/cava/<color>/config
~/.config/kitty/<color>_<font>/kitty.conf
~/.config/mako/<color>_<font>/config
~/.config/wofi/<color>_<font>/1/style.css
~/.config/wofi/<color>_<font>/2/style.css
~/.config/waybar/palettes/<color>.palette
```

`dotctl list colors` will pick the new color up the next time it runs,
and `dotctl set -c <color>` will apply it.

### New wallpaper theme

Two ways:

```sh
# Scaffold and edit IMAGES=() by hand for curated cycle order:
dotctl new wallpaper forest
cp ~/Downloads/*.jpg ~/Pictures/dotctl/wallpapers/forest/
$EDITOR ~/.config/dotctl/cycle/cycle-hyprpaper-forest
dotctl set -w forest

# Bulk-import alphabetized themes:
mkdir ~/Pictures/dotctl/wallpapers/{forest,retrowave}
cp ~/Downloads/forest/*    ~/Pictures/dotctl/wallpapers/forest/
cp ~/Downloads/retrowave/* ~/Pictures/dotctl/wallpapers/retrowave/
dotctl scan                               # generates both cycle scripts
dotctl set -w forest
```

`dotctl scan --dry-run` previews without writing. `dotctl scan --prefix
~/Downloads/wallpaper-pack` scans a non-canonical directory and
hardcodes that path into the generated cycle scripts so a pack can be
used in place without moving it.

### New font

Drop `~/.config/kitty/<color>_<font>/`, `~/.config/mako/<color>_<font>/`,
`~/.config/wofi/<color>_<font>/<variant>/`, and a matching
`~/.config/waybar/fonts/<font>.fontdef`. `dotctl list fonts` will find it.

## Troubleshooting

**`dotctl configure` refuses to run on first use.**
State doesn't exist yet. Run `dotctl configure` once to seed it.

**`dotctl set --waybar-vpn on` errors with "module not installed".**
The VPN module is opt-in at install time. Re-run `install.sh` and pick
"yes" at the VPN gate, or manually symlink `vpnctl` and
`vpn-status-indicator` from `stage/modules/` onto `PATH`.

**Waybar launcher / power click does nothing.**
Make sure `power` and `launcher` are on `PATH`:
`command -v power launcher`. They're symlinked into `/usr/local/bin/`
by `install.sh`.

**Man page is stale after updating dotctl.**
Some older installers dropped an uncompressed `/usr/local/share/man/man1/dotctl.1`
that shadows the gzipped current copy. Re-run `install.sh` - it now
removes the stale sibling. Or manually:
`sudo rm -f /usr/local/share/man/man1/dotctl.1 && sudo mandb -q`.

**Kitty config reappears after uninstall.**
A running kitty process may be auto-recreating `~/.config/kitty/`. Close
all kitty windows first, then re-run `./uninstall.sh` - it will warn
instead of silently failing in this case.

**Hyprland doesn't pick up color changes.**
Check that `source = ~/.config/hypr/dotctl-colors.conf` is at the
**bottom** of `hyprland.conf` (later sources override earlier ones),
then `hyprctl reload`. `dotctl apply` re-writes that file and tries to
reload hyprland automatically.

## Uninstall

```sh
./uninstall.sh
```

Removes the system symlinks, the man page (both `.1` and `.1.gz` forms),
the hyprland snippets, and the data template. Prompts individually
before removing any user data under `~/.config/dotctl/`,
`~/.config/{cava,kitty,mako,wofi,waybar}/`, and
`~/Pictures/dotctl/wallpapers/`. Symlinks in `/usr/local/bin/` that
happen to share a name with a module but point outside the repo are
left alone.

Finally, remove the two `source = ` lines you added to
`~/.config/hypr/hyprland.conf`, then `hyprctl reload`.

## Layout

```
dotctl/
├── install.sh                installer (interactive)
├── uninstall.sh              uninstaller (interactive)
├── cava_config/              cava theme sources  (<color>/config)
├── kitty_config/             kitty theme sources (<color>_<font>/kitty.conf)
├── mako_config/              mako theme sources  (<color>_<font>/config)
├── wofi_config/              wofi theme sources  (<color>_<font>/<variant>/style.css)
├── waybar_config/
│   ├── console_full/         canonical waybar variants (config.jsonc + style.css)
│   ├── console_minimal/
│   ├── pill_full/
│   ├── pill_minimal/
│   ├── palettes/             <color>.palette files (injected at apply time)
│   ├── fonts/                <font>.fontdef files
│   └── decorators/           <decor>.glyphs files (console-only)
├── fonts/                    bundled TTFs (meslo, phoenix)
├── wallpapers/               bundled wallpaper packs
└── stage/                    everything that gets installed
    ├── dotctl                the CLI (single bash script)
    ├── dotctl.1              the man page (source; installed gzipped)
    ├── modules/              power, launcher, cputemp, gputemp, audio-*, vpnctl, …
    ├── cycle/                cycle-hyprpaper-* scripts + _cycle-hyprpaper.template
    ├── hypr/                 sourceable hyprland snippets + color template
    └── snippets/             extras (waybar css/jsonc snippets, vpn setup README)
```

## Reference

- `man dotctl`
- `dotctl help`
- `dotctl <command> --help`
- `dotctl list help`

## License

dotctl is licensed under the GNU General Public License v3.0 or later.
See the [LICENSE](./LICENSE) file for full details.

Bundled wallpapers are sourced from Unsplash (Unsplash License); per-image
photographer credits and source links live alongside the wallpaper sets and
cycle scripts. Bundled fonts retain their upstream licenses.
