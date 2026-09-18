#!/bin/bash
# System services + firewall, mirroring upstream install/config/*.sh.
# Skipped entirely in containers (no systemd user instance to manage).

set -euo pipefail
source "$OMARCHY_DEBIAN_ROOT/lib/log.sh"
source "$OMARCHY_DEBIAN_ROOT/lib/detect.sh"
source "$OMARCHY_DEBIAN_ROOT/lib/apt.sh"

detect_distro

if is_container; then
  log "container: skipping service management"
  exit 0
fi

if [[ ${OMARCHY_DEBIAN_DRY_RUN:-0} == "1" ]]; then
  log "dry-run: would enable cups, avahi, NetworkManager, docker.socket, ufw, sddm, power-profiles-daemon"
  exit 0
fi

enable_if_present() {
  local unit="$1"
  if systemctl list-unit-files "$unit" >/dev/null 2>&1; then
    $SUDO systemctl enable "$unit" 2>/dev/null || warn "could not enable $unit"
  fi
}

for unit in cups.service avahi-daemon.service NetworkManager.service \
  docker.socket power-profiles-daemon.service systemd-oomd.service; do
  enable_if_present "$unit"
done

# Don't let boot block on network association.
if systemctl list-unit-files NetworkManager-wait-online.service >/dev/null 2>&1; then
  $SUDO systemctl mask NetworkManager-wait-online.service 2>/dev/null || true
fi

# Display manager (only when the desktop phase installed sddm).
if command -v sddm >/dev/null && [[ ${OMARCHY_DEBIAN_NO_DESKTOP:-0} != "1" ]]; then
  $SUDO systemctl enable sddm.service 2>/dev/null || true
  # Match upstream's login/sddm.sh: don't let password login create an
  # encrypted keyring that fights the passwordless default keyring.
  if [[ -f /etc/pam.d/sddm ]]; then
    $SUDO sed -i '/-auth.*pam_gnome_keyring\.so/d;/-password.*pam_gnome_keyring\.so/d' /etc/pam.d/sddm
  fi
fi

# Firewall (upstream firewall.sh): deny incoming, allow outgoing, LocalSend.
if command -v ufw >/dev/null; then
  $SUDO ufw default deny incoming >/dev/null || true
  $SUDO ufw default allow outgoing >/dev/null || true
  $SUDO ufw allow 53317 >/dev/null || true # LocalSend tcp+udp
  $SUDO sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/ufw/ufw.conf 2>/dev/null || true
  $SUDO systemctl enable ufw.service 2>/dev/null || true
fi

# systemd-resolved: Debian doesn't always run it; enable only when already
# wired up to avoid breaking resolv.conf.
if systemctl is-enabled systemd-resolved.service >/dev/null 2>&1; then
  $SUDO systemctl enable systemd-resolved.service 2>/dev/null || true
fi
