#!/bin/bash
# Preflight: ensure the apt metadata is usable and core tools exist.

set -euo pipefail
source "$OMARCHY_DEBIAN_ROOT/lib/log.sh"
source "$OMARCHY_DEBIAN_ROOT/lib/detect.sh"
source "$OMARCHY_DEBIAN_ROOT/lib/apt.sh"

detect_distro

log "preflight: apt metadata + prerequisites"
apt_update_once

# Needed before anything else can resolve. software-properties-common is
# Ubuntu-only (provides add-apt-repository); on Debian it simply doesn't exist.
apt_install ca-certificates curl git lsb-release sudo
if apt_available software-properties-common; then
  apt_install software-properties-common
fi

# Debian proper needs contrib/non-free enabled for firmware, NVIDIA, and a few
# packages in extra.map. Ubuntu enables universe/multiverse via add-apt-repository.
if [[ $DISTRO_ID == "debian" && ${OMARCHY_DEBIAN_DRY_RUN:-0} != "1" ]]; then
  if ! grep -qE "non-free" /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null; then
    warn "non-free/contrib components not detected — firmware and NVIDIA packages will be unavailable."
    warn "add 'contrib non-free non-free-firmware' to your apt sources, then re-run."
  fi
fi

if [[ $DISTRO_ID == "ubuntu" && ${OMARCHY_DEBIAN_DRY_RUN:-0} != "1" ]]; then
  for comp in universe multiverse; do
    if ! apt-cache policy 2>/dev/null | grep -q "$comp"; then
      log "enabling apt component: $comp"
      $SUDO add-apt-repository -y "$comp" || warn "could not enable $comp"
    fi
  done
fi
