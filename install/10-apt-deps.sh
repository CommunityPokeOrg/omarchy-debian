#!/bin/bash
# Resolve packages/*.map against the local apt indexes and install everything
# that maps to a Debian package. Skipped/manual/external entries are reported.

set -euo pipefail
source "$OMARCHY_DEBIAN_ROOT/lib/log.sh"
source "$OMARCHY_DEBIAN_ROOT/lib/detect.sh"
source "$OMARCHY_DEBIAN_ROOT/lib/apt.sh"
source "$OMARCHY_DEBIAN_ROOT/lib/map.sh"

detect_distro
apt_update_once

resolve_map() {
  local mapfile="$1" resolved unresolved
  resolved=$(mktemp)
  unresolved=$(mktemp)
  resolve_apt_packages "$mapfile" >"$resolved" 2>"$unresolved"

  local -a wanted=()
  local pkg
  declare -A seen=()
  while IFS= read -r pkg; do
    if [[ -n $pkg && -z ${seen[$pkg]:-} ]]; then
      wanted+=("$pkg")
      seen[$pkg]=1
    fi
  done <"$resolved"

  if ((${#wanted[@]})); then
    apt_install "${wanted[@]}"
  fi

  if [[ -s $unresolved ]]; then
    warn "unresolved entries in ${mapfile##*/}:"
    sed 's/^/  /' "$unresolved" >&2
  fi
  rm -f "$resolved" "$unresolved"
}

resolve_map "$OMARCHY_DEBIAN_ROOT/packages/base.map"

# extra.map entries are largely driver/optional hardware packages. Only install
# the apt-resolvable ones unconditionally-safe ones here; firmware/NVIDIA are
# deferred to the hardware phase they belong to.
resolve_map "$OMARCHY_DEBIAN_ROOT/packages/extra.map" || true

# Debian names some tools differently; add the convenience symlinks omarchy
# scripts expect.
mkdir -p "$HOME/.local/bin"
if command -v batcat >/dev/null && [[ ! -e $HOME/.local/bin/bat ]]; then
  [[ ${OMARCHY_DEBIAN_DRY_RUN:-0} == "1" ]] && log "dry-run: link batcat -> ~/.local/bin/bat" ||
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
fi
if command -v fdfind >/dev/null && [[ ! -e $HOME/.local/bin/fd ]]; then
  [[ ${OMARCHY_DEBIAN_DRY_RUN:-0} == "1" ]] && log "dry-run: link fdfind -> ~/.local/bin/fd" ||
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi

# Report everything that did not come from apt so the user can act on it.
log "non-apt entries (see docs/MAPPING.md and docs/MANUAL-STEPS.md):"
list_non_apt "$OMARCHY_DEBIAN_ROOT/packages/base.map" | while IFS=$'\t' read -r pkg strategy arg notes; do
  log "  $pkg [$strategy] ${notes:-$arg}"
done
