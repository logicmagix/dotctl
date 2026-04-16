#!/usr/bin/env bash
# dotctl uninstaller
#
# Removes symlinks and installed files that point into the repo. Leaves
# user configs in ~/.config/{cava,kitty,mako,wofi,waybar} alone unless
# you explicitly confirm - those may have been edited post-install.

set -euo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
STAGE="$REPO/stage"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
SYS_BIN="/usr/local/bin"
SYS_MAN="/usr/local/share/man/man1"

if [[ -t 1 ]]; then
  BOLD=$'\e[1m'; DIM=$'\e[2m'; RED=$'\e[31m'; GRN=$'\e[32m'; YLW=$'\e[33m'
  CYN=$'\e[36m'; RST=$'\e[0m'
else
  BOLD=''; DIM=''; RED=''; GRN=''; YLW=''; CYN=''; RST=''
fi
info(){ printf '%s[dotctl]%s %s\n' "$CYN" "$RST" "$*"; }
warn(){ printf '%s[dotctl]%s %s\n' "$YLW" "$RST" "$*" >&2; }
ok()  { printf '  %s✓%s %s\n' "$GRN" "$RST" "$*"; }
skip(){ printf '  %s·%s %s\n' "$DIM" "$RST" "$*"; }
die() { printf '%s[dotctl]%s %s\n' "$RED" "$RST" "$*" >&2; exit 1; }

confirm() {
  local prompt="${1:-Continue?}" default="${2:-n}" reply hint='[y/N]'
  [[ "$default" == "y" ]] && hint='[Y/n]'
  read -r -p "$prompt $hint " reply || true
  reply="${reply:-$default}"
  [[ "$reply" =~ ^[Yy] ]]
}

cat <<BANNER
${BOLD}dotctl uninstaller${RST}
   ${DIM}repo:${RST} $REPO

This will remove:
  - $SYS_BIN/{dotctl, power, launcher, cputemp, gputemp, audio-*, vpnctl, vpn-status-indicator}
  - $SYS_MAN/dotctl.1.gz
  - $DATA_HOME/dotctl/dotctl-colors.conf.tmpl
  - $CONFIG_HOME/hypr/{dotctl-keybinds.conf, dotctl-colors.conf}

Only symlinks that point ${BOLD}into the repo${RST} are removed - unrelated
binaries with the same name are left alone.

Optional (prompted individually):
  - $CONFIG_HOME/dotctl/                       (state + cycle scripts + presets)
  - $CONFIG_HOME/{cava, kitty, mako, wofi, waybar, tty-clock}   (element configs)
  - $HOME/Pictures/dotctl/wallpapers/
  - tty-clock binary / VPN helpers             (package-remove, dotctl-specific only)

Shared runtime deps (waybar, cava, kitty, mako, wofi, jq, wl-clipboard,
lm-sensors, libnotify, pavucontrol, inotify-tools, fonts) are ${BOLD}never${RST}
package-removed by this script - Hyprland users typically want to keep them.

BANNER

confirm "Proceed?" n || die "aborted"

# ── sudo tick ───────────────────────────────────────────────────────────────

if [[ $EUID -ne 0 ]]; then
  info "Requesting sudo for system-level removals…"
  sudo -v || die "sudo required for $SYS_BIN removals"
  SUDO=sudo
else
  SUDO=""
fi

# ── Helper: remove symlink only if it resolves into our repo ────────────────

unlink_if_repo() {
  local link="$1" target
  if [[ -L "$link" ]]; then
    target="$(readlink -f "$link" 2>/dev/null || true)"
    if [[ "$target" == "$REPO"/* ]]; then
      $SUDO rm -f "$link"
      ok "removed $link"
    else
      skip "$link points outside the repo - kept"
    fi
  elif [[ -e "$link" ]]; then
    skip "$link is not a symlink - kept (remove manually if you want)"
  else
    skip "$link absent"
  fi
}

# ── Remove system binaries ──────────────────────────────────────────────────

info "Removing system binaries from $SYS_BIN/…"
for m in "$STAGE"/modules/*; do
  name="$(basename "$m")"
  unlink_if_repo "$SYS_BIN/$name"
done
unlink_if_repo "$SYS_BIN/dotctl"

# ── Remove man page ─────────────────────────────────────────────────────────
# Remove both the gzipped form (current installer) and the plain form
# (older installers and hand-installs). Refresh mandb regardless.

man_removed=0
for f in "$SYS_MAN/dotctl.1.gz" "$SYS_MAN/dotctl.1"; do
  if [[ -e "$f" ]]; then
    $SUDO rm -f "$f"
    ok "removed $f"
    man_removed=1
  fi
done
if (( man_removed == 1 )); then
  $SUDO mandb -q "$SYS_MAN/.." 2>/dev/null || true
else
  skip "no man page to remove"
fi

# ── Remove data files ───────────────────────────────────────────────────────

if [[ -f "$DATA_HOME/dotctl/dotctl-colors.conf.tmpl" ]]; then
  rm -f "$DATA_HOME/dotctl/dotctl-colors.conf.tmpl"
  rmdir "$DATA_HOME/dotctl" 2>/dev/null || true
  ok "removed $DATA_HOME/dotctl/dotctl-colors.conf.tmpl"
fi

# ── Remove hypr snippets ────────────────────────────────────────────────────

for f in "$CONFIG_HOME/hypr/dotctl-keybinds.conf" "$CONFIG_HOME/hypr/dotctl-colors.conf"; do
  if [[ -f "$f" ]]; then
    rm -f "$f"
    ok "removed $f"
  fi
done

# ── Optional user-data removals ─────────────────────────────────────────────

echo
info "Optional removals (each prompted individually):"

if [[ -d "$CONFIG_HOME/dotctl" ]]; then
  if confirm "  Remove $CONFIG_HOME/dotctl/ (state, presets, cycle scripts)?" n; then
    rm -rf "$CONFIG_HOME/dotctl"
    ok "removed $CONFIG_HOME/dotctl/"
  else
    skip "kept $CONFIG_HOME/dotctl/"
  fi
fi

for elem in cava kitty mako wofi waybar tty-clock; do
  if [[ -d "$CONFIG_HOME/$elem" ]]; then
    if confirm "  Remove $CONFIG_HOME/$elem/ ?" n; then
      # Harden against read-only files before removing, then verify the
      # dir is actually gone. Running apps (notably kitty) can re-create
      # their config dir immediately after rm - warn instead of dying so
      # the rest of uninstall still runs.
      chmod -R u+w "$CONFIG_HOME/$elem" 2>/dev/null || true
      rm -rf "$CONFIG_HOME/$elem"
      if [[ -e "$CONFIG_HOME/$elem" ]]; then
        warn "$CONFIG_HOME/$elem/ reappeared after removal - a running $elem process likely recreated it. Close all $elem windows and remove it manually:  rm -rf $CONFIG_HOME/$elem"
      else
        ok "removed $CONFIG_HOME/$elem/"
      fi
    else
      skip "kept $CONFIG_HOME/$elem/"
    fi
  fi
done

if [[ -d "$HOME/Pictures/dotctl/wallpapers" ]]; then
  if confirm "  Remove $HOME/Pictures/dotctl/wallpapers/ ?" n; then
    rm -rf "$HOME/Pictures/dotctl"
    ok "removed $HOME/Pictures/dotctl/"
  else
    skip "kept $HOME/Pictures/dotctl/"
  fi
fi

# ── Optional package removal (dotctl-introduced deps only) ──────────────────
# We only prompt for packages the installer itself introduced as opt-in
# (tty-clock, VPN helpers). Shared Hyprland-stack packages (waybar, cava,
# kitty, mako, wofi, jq, wl-clipboard, lm-sensors, libnotify, pavucontrol,
# inotify-tools) are left alone - removing them here would likely break
# other parts of the user's desktop.

detect_pkg_remove_cmd() {
  REMOVE_CMD=()
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}" in
      gentoo)                                  REMOVE_CMD=(sudo emerge --unmerge) ;;
      arch|cachyos|endeavouros|manjaro|artix)  REMOVE_CMD=(sudo pacman -Rns --noconfirm) ;;
      debian|ubuntu|linuxmint|pop)             REMOVE_CMD=(sudo apt remove -y) ;;
      fedora|nobara)                           REMOVE_CMD=(sudo dnf remove -y) ;;
      opensuse*|suse*|sles)                    REMOVE_CMD=(sudo zypper remove -y) ;;
      void)                                    REMOVE_CMD=(sudo xbps-remove -Ry) ;;
      slackware)                               REMOVE_CMD=(sudo slackpkg remove) ;;
      nixos)                                   REMOVE_CMD=() ;;
      *)                                       REMOVE_CMD=() ;;
    esac
  fi
}

detect_pkg_remove_cmd

pkg_remove() {
  local pkg="$1"
  if (( ${#REMOVE_CMD[@]} == 0 )); then
    warn "no known package-remove command for this distro - remove $pkg manually"
    return 1
  fi
  "${REMOVE_CMD[@]}" "$pkg" || warn "$pkg remove failed (already gone? held back?) - check output above"
}

echo
info "Optional package removal (dotctl-specific only - shared deps are preserved):"

if command -v tty-clock >/dev/null 2>&1; then
  if confirm "  Package-remove tty-clock?" n; then
    pkg_remove tty-clock && ok "tty-clock package removed"
  else
    skip "kept tty-clock binary"
  fi
else
  skip "tty-clock not installed"
fi

if command -v vpnctl >/dev/null 2>&1 || command -v vpn-status-indicator >/dev/null 2>&1; then
  # vpnctl/vpn-status-indicator are repo scripts, not distro packages - the
  # earlier unlink_if_repo loop already handled them. Nothing to package-remove.
  skip "vpn helpers are repo scripts, already handled in the symlink pass"
fi

cat <<DONE

${BOLD}${GRN}dotctl uninstalled.${RST}

${DIM}Remove these lines from ~/.config/hypr/hyprland.conf if you added them:${RST}

    source = ~/.config/hypr/dotctl-keybinds.conf
    source = ~/.config/hypr/dotctl-colors.conf

${DIM}Then: hyprctl reload${RST}

DONE
