#!/usr/bin/env bash
# dotctl installer
#
# Symlinks the scripts in stage/ to /usr/local/bin (+ user VPN scripts to
# ~/.local/bin), copies configs to ~/.config/, drops the keybind + hypr
# color snippets alongside your hyprland config, and installs optional
# wallpapers. Nothing in this script touches hyprland.conf itself — the
# post-install block tells you which one-liners to add manually.

set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────────────

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
STAGE="$REPO/stage"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
SYS_BIN="/usr/local/bin"
SYS_MAN="/usr/local/share/man/man1"

# ── Output helpers ───────────────────────────────────────────────────────────

if [[ -t 1 ]]; then
  BOLD=$'\e[1m'; DIM=$'\e[2m'; RED=$'\e[31m'; GRN=$'\e[32m'; YLW=$'\e[33m'
  CYN=$'\e[36m'; RST=$'\e[0m'
else
  BOLD=''; DIM=''; RED=''; GRN=''; YLW=''; CYN=''; RST=''
fi

info()  { printf '%s[dotctl]%s %s\n' "$CYN" "$RST" "$*"; }
warn()  { printf '%s[dotctl]%s %s\n' "$YLW" "$RST" "$*" >&2; }
err()   { printf '%s[dotctl]%s %s\n' "$RED" "$RST" "$*" >&2; }
ok()    { printf '  %s✓%s %s\n' "$GRN" "$RST" "$*"; }
skip()  { printf '  %s·%s %s\n' "$DIM" "$RST" "$*"; }
die()   { err "$*"; exit 1; }

confirm() {
  local prompt="${1:-Continue?}" default="${2:-n}" reply hint='[y/N]'
  [[ "$default" == "y" ]] && hint='[Y/n]'
  read -r -p "$prompt $hint " reply || true
  reply="${reply:-$default}"
  [[ "$reply" =~ ^[Yy] ]]
}

# ── Banner ───────────────────────────────────────────────────────────────────

cat <<BANNER
${BOLD}dotctl installer${RST}
   ${DIM}repo:${RST} $REPO

This script will:
  1. Verify hyprland + hyprpaper are installed (hard requirement)
  2. Optionally install runtime packages (waybar, cava, kitty, mako, wofi, …)
  3. Symlink ${BOLD}$SYS_BIN/${RST}{dotctl, power, launcher, cputemp, gputemp,
     audio-output, audio-output-menu, audio-hotplug-watch} → repo
  4. Optionally symlink ${BOLD}$SYS_BIN/${RST}{vpnctl, vpn-status-indicator} → repo
  5. Copy ${BOLD}~/.config/${RST}{cava, kitty, mako, wofi, waybar} from repo config dirs
  6. Copy ${BOLD}~/.config/dotctl/cycle/${RST} (wallpaper cycle scripts + template)
  7. Copy ${BOLD}~/.config/hypr/${RST}{dotctl-keybinds.conf, dotctl-colors.conf} snippets
     (you wire them yourself with one-line source= directives)
  8. Copy the man page to $SYS_MAN/dotctl.1.gz
  9. Copy wallpapers to ~/Pictures/dotctl/wallpapers/ (~61 MB, required for
     dotctl configure to find at least one theme)

${DIM}sudo is requested once for the system steps (3, 4, 8). Everything else runs as you.${RST}

BANNER

confirm "Proceed?" n || die "aborted"

# ── Prerequisites ────────────────────────────────────────────────────────────

info "Checking prerequisites…"
MISSING=()
for bin in hyprland hyprpaper; do
  if command -v "$bin" >/dev/null 2>&1; then
    ok "$bin found"
  else
    MISSING+=("$bin")
    err "$bin not found"
  fi
done
if (( ${#MISSING[@]} > 0 )); then
  err "Install ${MISSING[*]} first, then re-run this script."
  exit 1
fi

# ── OS / package manager detection ───────────────────────────────────────────

detect_os_and_pkg() {
  OS="$(uname -s)"
  case "$OS" in
    Linux)
      if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        DISTRO_ID="${ID:-linux}"
      else
        DISTRO_ID="linux"
      fi

      case "$DISTRO_ID" in
        gentoo)
          PKG_MANAGER="emerge"
          INSTALL_CMD=(sudo emerge --ask=n --quiet-build --noreplace)
          UPDATE_CMD=(sudo emerge --sync)
          ;;
        arch|cachyos|endeavouros|manjaro|artix)
          PKG_MANAGER="pacman"
          INSTALL_CMD=(sudo pacman -S --noconfirm --needed)
          UPDATE_CMD=(sudo pacman -Sy)
          ;;
        debian|ubuntu|linuxmint|pop)
          PKG_MANAGER="apt"
          INSTALL_CMD=(sudo apt install -y)
          UPDATE_CMD=(sudo apt update)
          ;;
        fedora|nobara)
          PKG_MANAGER="dnf"
          INSTALL_CMD=(sudo dnf install -y)
          UPDATE_CMD=(sudo dnf check-update)
          ;;
        opensuse*|suse*|sles)
          PKG_MANAGER="zypper"
          INSTALL_CMD=(sudo zypper install -y)
          UPDATE_CMD=(sudo zypper refresh)
          ;;
        void)
          PKG_MANAGER="xbps"
          INSTALL_CMD=(sudo xbps-install -Sy)
          UPDATE_CMD=(sudo xbps-install -Sy)
          ;;
        nixos)
          PKG_MANAGER="nix"
          INSTALL_CMD=(echo "[nixos] please add to configuration.nix:")
          UPDATE_CMD=()
          ;;
        slackware)
          PKG_MANAGER="slackpkg"
          INSTALL_CMD=(sudo slackpkg install)
          UPDATE_CMD=(sudo slackpkg update)
          ;;
        *)
          PKG_MANAGER="unknown"
          INSTALL_CMD=()
          UPDATE_CMD=()
          ;;
      esac
      ;;
    *)
      PKG_MANAGER="unknown"
      INSTALL_CMD=()
      UPDATE_CMD=()
      DISTRO_ID="$OS"
      ;;
  esac
  info "OS: $OS  |  distro: $DISTRO_ID  |  pkg manager: $PKG_MANAGER"
}

detect_os_and_pkg

# ── Runtime package names per distro ────────────────────────────────────────

pkg_name() {
  # $1 = canonical name; returns distro-specific package name on stdout.
  local canonical="$1"
  case "$PKG_MANAGER" in
    emerge)
      case "$canonical" in
        waybar)        printf 'gui-apps/waybar\n' ;;
        cava)          printf 'media-sound/cava\n' ;;
        kitty)         printf 'x11-terms/kitty\n' ;;
        mako)          printf 'gui-apps/mako\n' ;;
        wofi)          printf 'gui-apps/wofi\n' ;;
        inotify-tools) printf 'sys-fs/inotify-tools\n' ;;
        jq)            printf 'app-misc/jq\n' ;;
        wl-clipboard)  printf 'gui-apps/wl-clipboard\n' ;;
      esac
      ;;
    pacman|apt|dnf|zypper|xbps|slackpkg)
      printf '%s\n' "$canonical"
      ;;
    *)
      printf '%s\n' "$canonical"
      ;;
  esac
}

# Canonical → binary the package provides (for already-installed detection)
pkg_binary() {
  case "$1" in
    waybar)        printf 'waybar\n' ;;
    cava)          printf 'cava\n' ;;
    kitty)         printf 'kitty\n' ;;
    mako)          printf 'mako\n' ;;
    wofi)          printf 'wofi\n' ;;
    inotify-tools) printf 'inotifywait\n' ;;
    jq)            printf 'jq\n' ;;
    wl-clipboard)  printf 'wl-copy\n' ;;
  esac
}

PKG_CANONICAL=( waybar cava kitty mako wofi inotify-tools jq wl-clipboard )

# ── Gate: install packages ──────────────────────────────────────────────────

if confirm "Update package manager and install runtime deps?" n; then
  if (( ${#UPDATE_CMD[@]} > 0 )); then
    info "Updating package manager…"
    "${UPDATE_CMD[@]}" || warn "update failed; continuing"
  fi

  TO_INSTALL=()
  for canonical in "${PKG_CANONICAL[@]}"; do
    bin="$(pkg_binary "$canonical")"
    if command -v "$bin" >/dev/null 2>&1; then
      skip "$canonical already installed"
    else
      TO_INSTALL+=( "$(pkg_name "$canonical")" )
    fi
  done

  if (( ${#TO_INSTALL[@]} == 0 )); then
    ok "all runtime deps already present"
  elif [[ "$PKG_MANAGER" == "unknown" ]]; then
    warn "Unknown package manager — please install these manually:"
    printf '  - %s\n' "${PKG_CANONICAL[@]}"
  else
    info "Installing: ${TO_INSTALL[*]}"
    "${INSTALL_CMD[@]}" "${TO_INSTALL[@]}" || warn "some packages failed — review output above"
  fi
else
  skip "package install skipped"
fi

# ── Gate: VPN module (opt-in) ───────────────────────────────────────────────

WANT_VPN=0
if confirm "Install the optional VPN module (vpnctl + vpn-status-indicator)?" n; then
  WANT_VPN=1
fi

# ── Sudo tick ───────────────────────────────────────────────────────────────

if [[ $EUID -ne 0 ]]; then
  info "Requesting sudo for system-level steps…"
  sudo -v || die "sudo required for symlinks in $SYS_BIN and man page install"
  SUDO=sudo
  # keep alive in the background for the duration of the script
  ( while true; do sleep 50; sudo -n -v 2>/dev/null || exit; done ) &
  SUDO_KEEPALIVE_PID=$!
  trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT
else
  SUDO=""
fi

# ── System symlinks — /usr/local/bin ────────────────────────────────────────

info "Installing system binaries to $SYS_BIN/ (symlinks → repo)…"

sys_link() {
  local target="$1" link="$2"
  [[ -e "$target" ]] || { warn "missing: $target"; return 1; }
  $SUDO ln -sf "$target" "$link"
  ok "$link → $target"
}

sys_link "$STAGE/dotctl" "$SYS_BIN/dotctl"

# Module scripts — everything in stage/modules/ except the VPN pair, which
# only installs when the user opted in at the gate above.
for m in "$STAGE"/modules/*; do
  name="$(basename "$m")"
  case "$name" in
    vpnctl|vpn-status-indicator)
      (( WANT_VPN == 1 )) || { skip "$name (vpn module opted out)"; continue; }
      ;;
  esac
  [[ -f "$m" ]] || continue
  sys_link "$m" "$SYS_BIN/$name"
done

# ── Man page ────────────────────────────────────────────────────────────────

if [[ -f "$STAGE/dotctl.1" ]]; then
  info "Installing man page…"
  TMP_MAN="$(mktemp)"
  gzip -c "$STAGE/dotctl.1" > "$TMP_MAN"
  # Older installers (and hand-installs) dropped an uncompressed dotctl.1
  # next to the .gz. Remove it so `man` doesn't keep serving the stale copy.
  if [[ -e "$SYS_MAN/dotctl.1" ]]; then
    $SUDO rm -f "$SYS_MAN/dotctl.1"
    skip "removed stale $SYS_MAN/dotctl.1 (uncompressed)"
  fi
  $SUDO install -Dm644 "$TMP_MAN" "$SYS_MAN/dotctl.1.gz"
  rm -f "$TMP_MAN"
  $SUDO mandb -q "$SYS_MAN/.." 2>/dev/null || true
  ok "$SYS_MAN/dotctl.1.gz"
else
  warn "dotctl.1 not found in stage/ — skipping man page"
fi

# ── User installs (no sudo) ─────────────────────────────────────────────────

info "Installing user configs to $CONFIG_HOME/…"

# Element config dirs — copy (not symlink) so user edits stay private.
copy_config() {
  local src="$1" dest="$2"
  [[ -d "$src" ]] || { warn "missing: $src"; return 1; }
  mkdir -p "$(dirname "$dest")"
  if [[ -d "$dest" ]]; then
    if confirm "  $dest exists — overwrite?" n; then
      rm -rf "$dest"
    else
      skip "kept existing $dest"
      return 0
    fi
  fi
  cp -a "$src" "$dest"
  ok "$dest"
}

copy_config "$REPO/cava_config"   "$CONFIG_HOME/cava"
copy_config "$REPO/kitty_config"  "$CONFIG_HOME/kitty"
copy_config "$REPO/mako_config"   "$CONFIG_HOME/mako"
copy_config "$REPO/wofi_config"   "$CONFIG_HOME/wofi"
copy_config "$REPO/waybar_config" "$CONFIG_HOME/waybar"

# Cycle scripts (copies — user curates IMAGES=() per theme)
info "Installing cycle scripts to $CONFIG_HOME/dotctl/cycle/…"
mkdir -p "$CONFIG_HOME/dotctl/cycle"
cp -a "$STAGE/cycle/." "$CONFIG_HOME/dotctl/cycle/"
chmod +x "$CONFIG_HOME/dotctl/cycle"/cycle-hyprpaper-*
ok "$CONFIG_HOME/dotctl/cycle/"

# Hypr color template — apply_hypr reads it from ~/.local/share/dotctl/
info "Installing hypr color template to $DATA_HOME/dotctl/…"
install -Dm644 "$STAGE/hypr/dotctl-colors.conf.tmpl" "$DATA_HOME/dotctl/dotctl-colors.conf.tmpl"
ok "$DATA_HOME/dotctl/dotctl-colors.conf.tmpl"

# Hypr snippets (keybinds + color stub). The color stub is a neutral-grey
# placeholder so hyprland's `source = ~/.config/hypr/dotctl-colors.conf`
# directive resolves immediately — `dotctl apply` overwrites it with real
# palette-driven values on first run.
if [[ -d "$CONFIG_HOME/hypr" ]]; then
  info "Installing hypr snippets to $CONFIG_HOME/hypr/…"
  cp -a "$STAGE/hypr/dotctl-keybinds.conf" "$CONFIG_HOME/hypr/dotctl-keybinds.conf"
  ok "$CONFIG_HOME/hypr/dotctl-keybinds.conf"

  if [[ ! -f "$CONFIG_HOME/hypr/dotctl-colors.conf" ]]; then
    cat > "$CONFIG_HOME/hypr/dotctl-colors.conf" <<'STUB'
# dotctl — placeholder hyprland color file (neutral grays)
# This file is overwritten by `dotctl apply` with palette-driven colors.
# Kept as a stub so hyprland's `source = ` directive always resolves.

general {
    col.active_border   = rgba(888888ee) rgba(aaaaaaee) 45deg
    col.inactive_border = rgba(333333aa)
}

decoration {
    shadow {
        color           = rgba(000000cc)
    }
}
STUB
    ok "$CONFIG_HOME/hypr/dotctl-colors.conf (bootstrap stub)"
  else
    skip "$CONFIG_HOME/hypr/dotctl-colors.conf already exists"
  fi
else
  warn "$CONFIG_HOME/hypr/ doesn't exist — skipping keybind + color snippets"
fi

# VPN scripts were handled in the main system symlink loop above — nothing
# extra to do here. `stage/snippets/vpn/README.md` documents OpenVPN setup.
if (( WANT_VPN == 1 )); then
  info "VPN setup docs: $STAGE/snippets/vpn/README.md"
fi

# ── Wallpapers ──────────────────────────────────────────────────────────────

PIC_ROOT="$HOME/Pictures/dotctl/wallpapers"

install_wallpaper_dir() {
  local name="$1"
  local src="$REPO/wallpapers/$name"
  local dest="$PIC_ROOT/$name"
  [[ -d "$src" ]] || { warn "wallpaper dir missing in repo: $name"; return 1; }
  mkdir -p "$dest"
  cp -an "$src"/* "$dest/" 2>/dev/null || true
  ok "wallpapers/$name"
}

info "Installing wallpapers to $PIC_ROOT/…"
mkdir -p "$PIC_ROOT"
for name in forest coyote tokyo_night gruvbox ocean; do
  install_wallpaper_dir "$name"
done

# ── Post-install summary ────────────────────────────────────────────────────

cat <<DONE

${BOLD}${GRN}dotctl installed.${RST}

${BOLD}Next steps:${RST}

1. Add these two lines to the ${BOLD}bottom${RST} of ~/.config/hypr/hyprland.conf
   (the bottom matters — later entries override earlier ones):

     ${CYN}source = ~/.config/hypr/dotctl-keybinds.conf${RST}
     ${CYN}source = ~/.config/hypr/dotctl-colors.conf${RST}

   Then: ${CYN}hyprctl reload${RST}

2. Run the first-time wizard:

     ${CYN}dotctl configure${RST}

3. Launch your bar if it isn't running:

     ${CYN}waybar & disown${RST}

${DIM}VPN module setup (if enabled): $STAGE/snippets/vpn/README.md${RST}

DONE
