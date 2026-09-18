#!/bin/bash
# omarchy-debian — Debian/Ubuntu adaptation of omacom/omarchy.
#
# Installs Omarchy's dependency set via apt (per packages/*.map), fetches the
# upstream repo read-only at a pinned commit, applies Debian overlay configs,
# and wires up a usable Wayland session (Hyprland where packaged, or Sway).
#
# Usage:
#   ./install.sh                 # interactive, full install
#   ./install.sh --yes           # assume yes; still logs every action
#   ./install.sh --dry-run       # resolve everything, change nothing
#   ./install.sh --no-desktop    # packages + dotfiles only, no compositor/DM
#   ./install.sh --compositor sway
#   ./install.sh --phases 10-apt-deps,50-dotfiles
#
# Everything is idempotent: re-running installs only what is missing and only
# deploys overlay files that differ.

set -euo pipefail

OMARCHY_DEBIAN_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export OMARCHY_DEBIAN_ROOT

# shellcheck source=lib/log.sh
source "$OMARCHY_DEBIAN_ROOT/lib/log.sh"
# shellcheck source=lib/detect.sh
source "$OMARCHY_DEBIAN_ROOT/lib/detect.sh"
# shellcheck source=lib/apt.sh
source "$OMARCHY_DEBIAN_ROOT/lib/apt.sh"
# shellcheck source=lib/map.sh
source "$OMARCHY_DEBIAN_ROOT/lib/map.sh"

export OMARCHY_DEBIAN_DRY_RUN=0
export OMARCHY_DEBIAN_ASSUME_YES=0
export OMARCHY_DEBIAN_NO_DESKTOP=0
export OMARCHY_DEBIAN_COMPOSITOR=auto
export OMARCHY_DEBIAN_STRICT=0
PHASES=()

while (($#)); do
  case "$1" in
    --yes | -y) OMARCHY_DEBIAN_ASSUME_YES=1 ;;
    --dry-run) OMARCHY_DEBIAN_DRY_RUN=1 ;;
    --no-desktop) OMARCHY_DEBIAN_NO_DESKTOP=1 ;;
    --strict) OMARCHY_DEBIAN_STRICT=1 ;;
    --compositor)
      shift
      OMARCHY_DEBIAN_COMPOSITOR="${1:?--compositor needs a value (auto|hyprland|sway)}"
      ;;
    --phases)
      shift
      IFS=',' read -ra PHASES <<<"${1:?--phases needs a comma-separated list}"
      ;;
    -h | --help)
      sed -n '2,22p' "$0"
      exit 0
      ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

if [[ $EUID -eq 0 ]]; then
  SUDO=""
else
  command -v sudo >/dev/null || die "sudo is required (or run as root)"
  if ! sudo -n true 2>/dev/null; then
    sudo -v 2>/dev/null || sudo true || die "sudo authentication failed"
  fi
  SUDO="sudo"
fi
export SUDO

detect_distro
log "omarchy-debian installer"
log "distro: $DISTRO_ID $DISTRO_VERSION ($DISTRO_CODENAME) — support: $SUPPORT_LEVEL"
[[ ${OMARCHY_DEBIAN_DRY_RUN} == "1" ]] && log "mode: dry-run (no changes will be made)"

if [[ $SUPPORT_LEVEL == "supported-backports" ]]; then
  log "note: the Hyprland stack will come from ${DISTRO_CODENAME}-backports"
fi
if [[ $SUPPORT_LEVEL == "unsupported" ]]; then
  warn "this Debian/Ubuntu release is untested; the package phase will still run,"
  warn "but the Wayland desktop pieces may be unavailable. See docs/LIMITATIONS.md."
fi
if is_container; then
  warn "container detected — systemd/service/desktop phases will be skipped"
fi

ALL_PHASES=(
  00-preflight.sh
  10-apt-deps.sh
  20-external.sh
  30-upstream.sh
  40-desktop.sh
  45-hardware.sh
  50-dotfiles.sh
  60-services.sh
  70-finish.sh
)

selected=("${ALL_PHASES[@]}")
if ((${#PHASES[@]})); then
  selected=("${PHASES[@]}")
fi

FAILED=()
for phase in "${selected[@]}"; do
  script="$OMARCHY_DEBIAN_ROOT/install/$phase"
  run_phase "$script" || FAILED+=("$phase")
done

if ((${#FAILED[@]})); then
  warn "failed phases: ${FAILED[*]}"
  warn "fix the reported issues and re-run: ./install.sh --phases $(IFS=,; echo "${FAILED[*]}")"
  exit 1
fi
log "install complete — see docs/MANUAL-STEPS.md for remaining manual items"
