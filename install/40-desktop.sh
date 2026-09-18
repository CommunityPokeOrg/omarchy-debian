#!/bin/bash
# Desktop stack: compositor (hyprland preferred, sway fallback), portal, uwsm,
# SDDM display manager, and the omarchy wayland session entry.

set -euo pipefail
source "$OMARCHY_DEBIAN_ROOT/lib/log.sh"
source "$OMARCHY_DEBIAN_ROOT/lib/detect.sh"
source "$OMARCHY_DEBIAN_ROOT/lib/apt.sh"

detect_distro

if [[ ${OMARCHY_DEBIAN_NO_DESKTOP:-0} == "1" ]]; then
  log "--no-desktop: skipping compositor/DM setup"
  exit 0
fi

want="${OMARCHY_DEBIAN_COMPOSITOR:-auto}"

# On Debian stable the Hyprland stack lives in <codename>-backports, not main.
# Enable it when needed so `apt-cache`/install see those packages.
APT_TARGET_ARGS=()
if [[ $SUPPORT_LEVEL == "supported-backports" && -n $DISTRO_CODENAME ]]; then
  bp="/etc/apt/sources.list.d/${DISTRO_CODENAME}-backports.sources"
  if [[ ! -f $bp && ${OMARCHY_DEBIAN_DRY_RUN:-0} != "1" ]]; then
    log "enabling ${DISTRO_CODENAME}-backports"
    printf 'Types: deb\nURIs: http://deb.debian.org/debian\nSuites: %s-backports\nComponents: main\nSigned-By: /usr/share/keyrings/debian-archive-keyring.gpg\n' \
      "$DISTRO_CODENAME" | $SUDO tee "$bp" >/dev/null
    omd_apt_updated=0
    apt_update_once
  fi
  APT_TARGET_ARGS=(-t "${DISTRO_CODENAME}-backports")
fi

apt_install_target() { # like apt_install but honoring APT_TARGET_ARGS
  local pkgs=("$@")
  ((${#pkgs[@]})) || return 0
  if [[ ${OMARCHY_DEBIAN_DRY_RUN:-0} == "1" ]]; then
    log "dry-run: apt-get install ${APT_TARGET_ARGS[*]} ${pkgs[*]}"
    return 0
  fi
  apt_update_once
  $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    --no-install-recommends "${APT_TARGET_ARGS[@]}" "${pkgs[@]}"
}

# Install the first apt-available package from a | list; warns otherwise.
apt_any() {
  local resolved
  if resolved=$(apt_first_available "$1"); then
    apt_install_target "$resolved"
  else
    warn "no candidate available in apt for: $1"
    return 1
  fi
}

have_hyprland=0
if [[ $want == "hyprland" || $want == "auto" ]]; then
  if [[ $SUPPORT_LEVEL == "supported-backports" ]] || apt_first_available "hyprland" >/dev/null; then
    have_hyprland=1
  elif [[ $want == "hyprland" ]]; then
    die "hyprland is not in the apt indexes for $DISTRO_ID $DISTRO_VERSION — see docs/MANUAL-STEPS.md"
  else
    warn "hyprland not packaged for $DISTRO_ID $DISTRO_VERSION"
    warn "options: build Hyprland from source (docs/MANUAL-STEPS.md) or fall back to sway"
  fi
fi

if ((have_hyprland)); then
  apt_install_target hyprland
  apt_any "uwsm" || warn "uwsm not packaged — the session entry falls back to plain Hyprland"
  apt_any "xdg-desktop-portal-hyprland|xdg-desktop-portal-wlr" || true
  apt_any "hyprlock|swaylock" || true
  apt_any "hypridle|swayidle" || true
  apt_any "hyprpaper|swaybg" || true
else
  # Sway fallback: packaged everywhere Debian/Ubuntu, gives a working tiling
  # Wayland session with the same dotfiles minus the Hyprland-specific pieces.
  if apt_first_available "sway" >/dev/null; then
    log "installing sway fallback session"
    apt_install sway swaybg swaylock swayidle xdg-desktop-portal-wlr fuzzel
  else
    die "neither hyprland nor sway is available in the apt indexes"
  fi
fi

# Notification + launcher + bar used by the overlay config. mako covers
# notifications; fuzzel is the app launcher stand-in for the Omarchy shell
# (which needs quickshell — see docs/LIMITATIONS.md).
apt_any "mako-notifier|dunst" || true
apt_any "fuzzel|wofi" || true
apt_any "waybar" || true
apt_any "cliphist" || true
apt_any "playerctl" || true

# SDDM display manager.
if [[ ${OMARCHY_DEBIAN_DRY_RUN:-0} != "1" ]] && ! is_container; then
  apt_install sddm
fi
