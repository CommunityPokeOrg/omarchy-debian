#!/bin/bash
# Dotfiles and overlay deployment.
#
# Upstream layout (unmodified clone at $OMARCHY_PATH):
#   config/   -> ~/.config/*           (hypr, alacritty, tmux, ...)
#   default/  -> shipped defaults      (bash rc, uwsm env, systemd units, ...)
#   bin/      -> omarchy-* commands    (added to PATH *after* overlay/bin)
#
# Debian overlay ($OMARCHY_DEBIAN_ROOT/overlay):
#   bin/      -> apt-backed replacements for the pacman/AUR omarchy-pkg-*
#   config/hypr/hyprland.conf -> classic-syntax config (upstream ships Lua that
#                                needs Hyprland >= 0.50; Debian packages 0.41)
#
# Everything is idempotent: existing user files are backed up once to
# <file>.pre-omarchy and only overwritten when they differ from the source.

set -euo pipefail
source "$OMARCHY_DEBIAN_ROOT/lib/log.sh"

: "${OMARCHY_PATH:=$HOME/.local/share/omarchy}"
OVERLAY="$OMARCHY_DEBIAN_ROOT/overlay"
DRY_RUN=${OMARCHY_DEBIAN_DRY_RUN:-0}

# copy with backup-if-differ; returns 0 when deployed
deploy_file() {
  local src="$1" dst="$2"
  if [[ $DRY_RUN == "1" ]]; then
    log "dry-run: deploy $src -> $dst"
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  if [[ -f $dst ]] && cmp -s "$src" "$dst"; then
    return 0 # already identical — idempotent no-op
  fi
  if [[ -f $dst && ! -f "$dst.pre-omarchy" ]]; then
    cp -a "$dst" "$dst.pre-omarchy"
    log "backed up $dst -> $dst.pre-omarchy"
  fi
  install -Dm644 "$src" "$dst" 2>/dev/null || install -Dm755 "$src" "$dst"
}

deploy_tree() { # <src-dir> <dst-dir>
  local src="$1" dst="$2" f rel
  [[ -d $src ]] || return 0
  while IFS= read -r -d '' f; do
    rel="${f#"$src"/}"
    deploy_file "$f" "$dst/$rel"
  done < <(find "$src" -type f -print0)
}

# --- 1. upstream user configs ------------------------------------------------
# Everything under upstream config/ maps to ~/.config/<name>. The hypr dir is
# skipped: upstream's Lua config needs Hyprland >= 0.50 (see overlay note).
if [[ -d $OMARCHY_PATH/config ]]; then
  for dir in "$OMARCHY_PATH"/config/*/; do
    name=$(basename "$dir")
    [[ $name == "hypr" ]] && continue # handled below
    deploy_tree "$dir" "$HOME/.config/$name"
  done
  for f in "$OMARCHY_PATH"/config/*; do
    [[ -f $f ]] && deploy_file "$f" "$HOME/.config/$(basename "$f")"
  done
else
  warn "upstream clone not found at $OMARCHY_PATH — skipping config deploy"
fi

# --- 2. overlay configs ------------------------------------------------------
deploy_tree "$OVERLAY/config" "$HOME/.config"
deploy_tree "$OVERLAY/uwsm" "$HOME/.config/uwsm"

# --- 3. system-level overlay files -------------------------------------------
if [[ $DRY_RUN != "1" ]]; then
  for f in "$OVERLAY"/wayland-sessions/*.desktop; do
    [[ -f $f ]] || continue
    $SUDO install -Dm644 "$f" "/usr/share/wayland-sessions/$(basename "$f")"
  done
  for f in "$OVERLAY"/environment.d/*.conf; do
    [[ -f $f ]] || continue
    $SUDO install -Dm644 "$f" "/etc/environment.d/$(basename "$f")"
  done
  for f in "$OVERLAY"/sddm.conf.d/*.conf; do
    [[ -f $f ]] || continue
    $SUDO install -Dm644 "$f" "/etc/sddm.conf.d/$(basename "$f")"
  done
else
  log "dry-run: would deploy session/environment.d/sddm files to system paths"
fi

# --- 4. shell hookup ----------------------------------------------------------
# ~/.bashrc sources upstream's bash defaults; OMARCHY_PATH + PATH (overlay bin
# first, then upstream bin) are exported before that.
MARKER="# >>> omarchy-debian >>>"
BASHRC_SNIPPET=$(cat <<EOF
$MARKER
export OMARCHY_PATH="$OMARCHY_PATH"
export OMARCHY_DEBIAN_PATH="$OMARCHY_DEBIAN_ROOT"
export PATH="$OVERLAY/bin:$OMARCHY_PATH/bin:\$HOME/.local/bin:\$PATH"
[ -r "$OMARCHY_PATH/default/bash/rc" ] && source "$OMARCHY_PATH/default/bash/rc"
# <<< omarchy-debian <<<
EOF
)

if [[ $DRY_RUN == "1" ]]; then
  log "dry-run: add omarchy block to ~/.bashrc"
else
  touch "$HOME/.bashrc"
  if ! grep -qF "$MARKER" "$HOME/.bashrc"; then
    printf '\n%s\n' "$BASHRC_SNIPPET" >>"$HOME/.bashrc"
    log "added omarchy block to ~/.bashrc"
  fi
fi

# --- 5. state dirs -------------------------------------------------------------
if [[ $DRY_RUN != "1" ]]; then
  mkdir -p "$HOME/.local/state/omarchy" "$HOME/.config/omarchy/themes" \
    "$HOME/.local/share/applications" "$HOME/Pictures/Screenshots"
fi

log "dotfiles deployed"
