#!/usr/bin/env bash
# dotctl uninstaller
#
# Each removal is individually confirmed. Element configs in
# ~/.config/{cava,kitty,mako,wofi,waybar} can be scrubbed too - if you keep
# them while removing the dotctl scripts they reference, waybar will log
# "failed to start module" errors for cputemp/gputemp/audio-*/ws-cycle. The
# wallpapers directory, $CONFIG_HOME/dotctl/ state, and install-time
# .bak-<timestamp> backups are never removed.

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

This script mirrors the installer's opt-in structure: each group below is
prompted individually, so you can peel off dotctl in pieces (e.g. keep the
VPN helpers but drop the rest). Nothing is removed without confirmation.

Groups you'll be asked about:
  - dotctl core scripts in $SYS_BIN
     (dotctl, power, launcher, cputemp, ws-cycle, audio-*, keybinds)
  - Optional modules that were opt-in at install time (VPN, GPU temp) -
    only prompted if currently symlinked
  - Element configs in $CONFIG_HOME/{cava, kitty, mako, wofi, waybar}
    (dotctl-shipped files only - your customizations and .bak-<ts> backups
    are preserved; empty dirs are removed)
  - Cycle scripts in $CONFIG_HOME/dotctl/cycle/
  - Hypr snippets in $CONFIG_HOME/hypr/
  - Man page at $SYS_MAN/dotctl.1.gz
  - Color template at $DATA_HOME/dotctl/

Only symlinks that point ${BOLD}into the repo${RST} are removed - unrelated
binaries with the same name are left alone.

${BOLD}Always left in place${RST} (remove by hand if you actually want them gone):
  - $HOME/Pictures/dotctl/wallpapers/
  - $CONFIG_HOME/dotctl/config and other non-cycle state
  - Any install-time ${BOLD}*.bak-<timestamp>${RST} backup files

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

# Returns 0 if the link exists and points into the repo (i.e. is installed
# by us and a candidate for removal). Used to decide whether to prompt for
# optional modules that were opt-in at install time.
link_points_to_repo() {
  local link="$1" target
  [[ -L "$link" ]] || return 1
  target="$(readlink -f "$link" 2>/dev/null || true)"
  [[ "$target" == "$REPO"/* ]]
}

# Split the module set so we can prompt per opt-in group instead of ripping
# every symlink out in one sweep. Anything not named here is treated as core.
CORE_MODULES=( power launcher cputemp ws-cycle audio-output audio-output-menu audio-output-status audio-hotplug-watch keybinds )
VPN_MODULES=( vpnctl vpn-status-indicator )
GPU_MODULES=( gputemp )

# ── Remove dotctl core scripts ──────────────────────────────────────────────

echo
if confirm "Remove dotctl core scripts (dotctl + ${CORE_MODULES[*]}) from $SYS_BIN/?" y; then
  unlink_if_repo "$SYS_BIN/dotctl"
  for name in "${CORE_MODULES[@]}"; do
    unlink_if_repo "$SYS_BIN/$name"
  done
else
  skip "kept dotctl core scripts in $SYS_BIN/"
fi

# ── Remove optional modules (only prompt for ones currently installed) ──────
# These were opt-in at install time, so we only bother the user about the
# ones they actually have symlinked.

vpn_present=0
for name in "${VPN_MODULES[@]}"; do
  link_points_to_repo "$SYS_BIN/$name" && { vpn_present=1; break; }
done
if (( vpn_present == 1 )); then
  echo
  if confirm "Remove VPN module (${VPN_MODULES[*]}) from $SYS_BIN/?" y; then
    for name in "${VPN_MODULES[@]}"; do
      unlink_if_repo "$SYS_BIN/$name"
    done
  else
    skip "kept VPN module symlinks"
  fi
fi

gpu_present=0
for name in "${GPU_MODULES[@]}"; do
  link_points_to_repo "$SYS_BIN/$name" && { gpu_present=1; break; }
done
if (( gpu_present == 1 )); then
  echo
  if confirm "Remove GPU temp module (${GPU_MODULES[*]}) from $SYS_BIN/?" y; then
    for name in "${GPU_MODULES[@]}"; do
      unlink_if_repo "$SYS_BIN/$name"
    done
  else
    skip "kept gputemp symlink"
  fi
fi

# Catch anything in stage/modules/ we didn't explicitly categorize above, so
# future additions aren't silently stranded. We still gate on a confirm.
declare -A KNOWN_MODULES=()
for n in "${CORE_MODULES[@]}" "${VPN_MODULES[@]}" "${GPU_MODULES[@]}"; do
  KNOWN_MODULES[$n]=1
done
EXTRA_PRESENT=()
for m in "$STAGE"/modules/*; do
  name="$(basename "$m")"
  [[ -n "${KNOWN_MODULES[$name]:-}" ]] && continue
  link_points_to_repo "$SYS_BIN/$name" && EXTRA_PRESENT+=( "$name" )
done
if (( ${#EXTRA_PRESENT[@]} > 0 )); then
  echo
  if confirm "Remove other dotctl module symlinks (${EXTRA_PRESENT[*]})?" y; then
    for name in "${EXTRA_PRESENT[@]}"; do
      unlink_if_repo "$SYS_BIN/$name"
    done
  else
    skip "kept extra module symlinks: ${EXTRA_PRESENT[*]}"
  fi
fi

# ── Remove man page ─────────────────────────────────────────────────────────
# Remove both the gzipped form (current installer) and the plain form
# (older installers and hand-installs). Refresh mandb regardless.

man_present=0
for f in "$SYS_MAN/dotctl.1.gz" "$SYS_MAN/dotctl.1"; do
  [[ -e "$f" ]] && { man_present=1; break; }
done
if (( man_present == 1 )); then
  echo
  if confirm "Remove the dotctl man page from $SYS_MAN/?" y; then
    man_removed=0
    for f in "$SYS_MAN/dotctl.1.gz" "$SYS_MAN/dotctl.1"; do
      if [[ -e "$f" ]]; then
        $SUDO rm -f "$f"
        ok "removed $f"
        man_removed=1
      fi
    done
    (( man_removed == 1 )) && $SUDO mandb -q "$SYS_MAN/.." 2>/dev/null || true
  else
    skip "kept man page"
  fi
fi

# ── Remove data files (color template) ──────────────────────────────────────

if [[ -f "$DATA_HOME/dotctl/dotctl-colors.conf.tmpl" ]]; then
  echo
  if confirm "Remove the hypr color template at $DATA_HOME/dotctl/dotctl-colors.conf.tmpl?" y; then
    rm -f "$DATA_HOME/dotctl/dotctl-colors.conf.tmpl"
    rmdir "$DATA_HOME/dotctl" 2>/dev/null || true
    ok "removed $DATA_HOME/dotctl/dotctl-colors.conf.tmpl"
  else
    skip "kept $DATA_HOME/dotctl/dotctl-colors.conf.tmpl"
  fi
fi

# ── Remove hypr snippets ────────────────────────────────────────────────────
# Hyprland will emit a parse error for a `source = …` line pointing at a
# missing file, so warn the user to strip those two lines from hyprland.conf
# after removal (already covered in the post-uninstall summary).

hypr_present=0
for f in "$CONFIG_HOME/hypr/dotctl-keybinds.conf" "$CONFIG_HOME/hypr/dotctl-colors.conf"; do
  [[ -f "$f" ]] && { hypr_present=1; break; }
done
if (( hypr_present == 1 )); then
  echo
  if confirm "Remove hypr snippets (dotctl-keybinds.conf, dotctl-colors.conf) from $CONFIG_HOME/hypr/?" y; then
    for f in "$CONFIG_HOME/hypr/dotctl-keybinds.conf" "$CONFIG_HOME/hypr/dotctl-colors.conf"; do
      if [[ -f "$f" ]]; then
        rm -f "$f"
        ok "removed $f"
      fi
    done
  else
    skip "kept hypr snippets"
  fi
fi

# ── Remove element configs (mirror of install copy_config) ──────────────────
# Walk each repo source dir; for every file we shipped, remove the target
# iff it still matches our copy byte-for-byte. User-modified files and
# user-added files are left alone. Empty dirs cleaned up after.
# This step exists because leaving configs active while removing the scripts
# they reference makes waybar spam "failed to start module" errors for
# cputemp/gputemp/audio-*/ws-cycle on every reload.

remove_shipped_files() {
  local src="$1" dest="$2"
  [[ -d "$src" && -d "$dest" ]] || return 0
  local f rel target kept=0
  while IFS= read -r -d '' f; do
    rel="${f#"$src"/}"
    target="$dest/$rel"
    [[ -e "$target" || -L "$target" ]] || continue
    if cmp -s "$f" "$target" 2>/dev/null; then
      rm -f "$target"
      ok "removed $target"
    else
      skip "$target diverged from repo - kept as your customization"
      kept=1
    fi
  done < <(find "$src" \( -type f -o -type l \) -print0)
  find "$dest" -mindepth 1 -depth -type d -empty -delete 2>/dev/null || true
  if (( kept == 0 )); then
    rmdir "$dest" 2>/dev/null || true
  fi
}

ELEMENT_CONFIGS=(
  "$REPO/cava_config:$CONFIG_HOME/cava"
  "$REPO/kitty_config:$CONFIG_HOME/kitty"
  "$REPO/mako_config:$CONFIG_HOME/mako"
  "$REPO/wofi_config:$CONFIG_HOME/wofi"
  "$REPO/waybar_config:$CONFIG_HOME/waybar"
)

element_present=0
for pair in "${ELEMENT_CONFIGS[@]}"; do
  [[ -d "${pair#*:}" ]] && { element_present=1; break; }
done
if (( element_present == 1 )); then
  echo
  if confirm "Remove dotctl-shipped element configs from $CONFIG_HOME/{cava,kitty,mako,wofi,waybar}? (your customizations and .bak-<ts> files are preserved)" y; then
    for pair in "${ELEMENT_CONFIGS[@]}"; do
      remove_shipped_files "${pair%%:*}" "${pair#*:}"
    done
  else
    skip "kept element configs"
    warn "heads up: waybar will log 'failed to start module' errors for cputemp/gputemp/audio-*/ws-cycle while the configs reference scripts you just removed"
  fi
fi

# ── Remove cycle scripts from $CONFIG_HOME/dotctl/cycle/ ────────────────────

if [[ -d "$CONFIG_HOME/dotctl/cycle" ]]; then
  echo
  if confirm "Remove dotctl-shipped cycle scripts from $CONFIG_HOME/dotctl/cycle/? (your curated IMAGES=() edits are preserved)" y; then
    remove_shipped_files "$STAGE/cycle" "$CONFIG_HOME/dotctl/cycle"
  else
    skip "kept cycle scripts"
  fi
fi

# ── Preserved paths + surviving backups ─────────────────────────────────────

echo
info "Leaving the following in place (remove by hand if desired):"
for p in \
  "$CONFIG_HOME/dotctl" \
  "$HOME/Pictures/dotctl/wallpapers"; do
  [[ -e "$p" ]] && skip "kept $p"
done

# Surface any .bak-* files so users know the backups survived. The file-level
# backups live inside the element config dirs; catch any leftover whole-dir
# backups from older installer versions too.
shopt -s nullglob
backups=(
  "$CONFIG_HOME"/cava/**/*.bak-*           "$CONFIG_HOME"/cava.bak-*
  "$CONFIG_HOME"/kitty/**/*.bak-*          "$CONFIG_HOME"/kitty.bak-*
  "$CONFIG_HOME"/mako/**/*.bak-*           "$CONFIG_HOME"/mako.bak-*
  "$CONFIG_HOME"/wofi/**/*.bak-*           "$CONFIG_HOME"/wofi.bak-*
  "$CONFIG_HOME"/waybar/**/*.bak-*         "$CONFIG_HOME"/waybar.bak-*
  "$CONFIG_HOME"/dotctl/cycle/**/*.bak-*   "$CONFIG_HOME"/dotctl/cycle.bak-*
  "$CONFIG_HOME"/hypr/dotctl-keybinds.conf.bak-*
)
shopt -u nullglob
if (( ${#backups[@]} > 0 )); then
  for b in "${backups[@]}"; do
    skip "kept backup $b"
  done
fi

cat <<DONE

${BOLD}${GRN}dotctl uninstalled.${RST}

${DIM}Remove these lines from ~/.config/hypr/hyprland.conf if you added them:${RST}

    source = ~/.config/hypr/dotctl-keybinds.conf
    source = ~/.config/hypr/dotctl-colors.conf

${DIM}Then: hyprctl reload${RST}

DONE
