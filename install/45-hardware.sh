#!/bin/bash
# Hardware-conditional packages (apt-hw entries in packages/extra.map).
# Installs drivers/firmware only when matching hardware is present; in
# containers/VMs most of this is skipped.

set -euo pipefail
source "$OMARCHY_DEBIAN_ROOT/lib/log.sh"
source "$OMARCHY_DEBIAN_ROOT/lib/detect.sh"
source "$OMARCHY_DEBIAN_ROOT/lib/apt.sh"
source "$OMARCHY_DEBIAN_ROOT/lib/map.sh"

detect_distro

if is_container; then
  log "container: skipping hardware packages"
  exit 0
fi

pci_devices() {
  if command -v lspci >/dev/null; then
    lspci -nn
  else
    cat /sys/bus/pci/devices/*/uevent 2>/dev/null || true
  fi
}

cpu_vendor() { grep -m1 vendor_id /proc/cpuinfo 2>/dev/null | awk '{print $3}'; }

PCI=$(pci_devices); CPU=$(cpu_vendor)
BARE_METAL=1
if is_virtual; then
  BARE_METAL=0
fi

want_pkg() { # install the apt-hw candidates for upstream pkg $1
  local pkg="$1" line candidates resolved
  line=$(list_hw_packages "$OMARCHY_DEBIAN_ROOT/packages/extra.map" | grep -F "$pkg	" | head -1)
  [[ -n $line ]] || return 0
  candidates=$(cut -f2 <<<"$line")
  if resolved=$(apt_first_available "$candidates"); then
    apt_install "$resolved"
  else
    warn "hardware detected for '$pkg' but no candidate in [$candidates] is available"
  fi
}

if ((BARE_METAL)); then
  want_pkg linux-firmware

  if [[ $CPU == "GenuineIntel" ]]; then
    want_pkg thermald
    want_pkg intel-media-driver
    want_pkg libva-intel-driver
    want_pkg libvpl
    want_pkg vpl-gpu-rt
    # SOF audio firmware when the DSP is present.
    if grep -qiE "sof|snd_sof" /proc/asound/cards /proc/modules 2>/dev/null ||
      echo "$PCI" | grep -qi "Multimedia audio controller"; then
      want_pkg sof-firmware
    fi
  fi

  if echo "$PCI" | grep -qi "VGA.*Intel\|3D.*Intel\|Display.*Intel"; then
    want_pkg vulkan-intel
  fi
  if echo "$PCI" | grep -qi "VGA.*AMD\|3D.*AMD\|VGA.*ATI"; then
    want_pkg vulkan-radeon
  fi

  if echo "$PCI" | grep -qi "NVIDIA"; then
    if [[ $DISTRO_ID == "ubuntu" ]] && command -v ubuntu-drivers >/dev/null; then
      log "NVIDIA GPU detected — install drivers via: ubuntu-drivers install"
      if [[ ${OMARCHY_DEBIAN_DRY_RUN:-0} != "1" && ${OMARCHY_DEBIAN_ASSUME_YES:-0} == "1" ]]; then
        $SUDO ubuntu-drivers install || warn "ubuntu-drivers install failed"
      else
        warn "run 'sudo ubuntu-drivers install' to install the recommended driver"
      fi
    else
      want_pkg nvidia-dkms
      want_pkg egl-wayland
      want_pkg libva-nvidia-driver
    fi
  fi

  if echo "$PCI" | grep -qi "Broadcom.*BCM43"; then
    want_pkg broadcom-wl-dkms
  fi
else
  log "virtualized environment — skipping firmware/driver packages"
fi
