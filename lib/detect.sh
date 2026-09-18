# shellcheck shell=bash
# Distro / environment detection for omarchy-debian.
# Source this file; do not execute it.

if [[ -n ${OMARCHY_DEBIAN_DETECT_LOADED:-} ]]; then
  return 0
fi
OMARCHY_DEBIAN_DETECT_LOADED=1

# Populates:
#   DISTRO_ID        e.g. "debian", "ubuntu"
#   DISTRO_VERSION   e.g. "13", "24.04"
#   DISTRO_CODENAME  e.g. "trixie", "noble"
#   DISTRO_FAMILY    "debian" for anything apt-based
#   SUPPORT_LEVEL    "supported" | "partial" | "unsupported"
detect_distro() {
  [[ -r /etc/os-release ]] || die "cannot detect OS: /etc/os-release missing"
  # shellcheck disable=SC1091
  . /etc/os-release

  DISTRO_ID="${ID:-unknown}"
  DISTRO_VERSION="${VERSION_ID:-0}"
  DISTRO_CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
  DISTRO_FAMILY="other"

  local ids="${ID:-} ${ID_LIKE:-}"
  case " $ids " in
    *" debian "*) DISTRO_FAMILY="debian" ;;
  esac
  [[ $DISTRO_ID == "ubuntu" || $DISTRO_ID == "debian" ]] && DISTRO_FAMILY="debian"
  [[ $DISTRO_FAMILY == "debian" ]] || die "unsupported distro '$DISTRO_ID': omarchy-debian targets Debian/Ubuntu only"
  command -v apt-get >/dev/null || die "apt-get not found; this installer requires a Debian/Ubuntu system"

  SUPPORT_LEVEL="unsupported"
  case "$DISTRO_ID" in
    debian)
      # The Hyprland stack lives in trixie-backports (not main). forky/sid
      # carry it directly.
      if [[ ${DISTRO_VERSION%%.*} -ge 14 ]]; then
        SUPPORT_LEVEL="supported"
      elif [[ ${DISTRO_VERSION%%.*} -eq 13 || $DISTRO_CODENAME == "trixie" ]]; then
        SUPPORT_LEVEL="supported-backports"
      elif [[ ${DISTRO_VERSION%%.*} -eq 12 ]]; then
        SUPPORT_LEVEL="partial" # bookworm: no hyprland in the archive
      fi
      ;;
    ubuntu)
      case "$DISTRO_VERSION" in
        24.10 | 25.* | 26.*) SUPPORT_LEVEL="supported" ;; # hyprland in universe
        24.04) SUPPORT_LEVEL="partial" ;;                 # noble: no hyprland
        *) ;;
      esac
      ;;
    *)
      # Derivatives (Linux Mint, Pop!_OS, ...): treat as partial; the apt
      # mapping still applies but the compositor may be missing.
      if [[ " $ids " == *" ubuntu "* ]]; then
        SUPPORT_LEVEL="partial"
      elif [[ " $ids " == *" debian "* ]]; then
        SUPPORT_LEVEL="partial"
      fi
      ;;
  esac

  export DISTRO_ID DISTRO_VERSION DISTRO_CODENAME DISTRO_FAMILY SUPPORT_LEVEL
}

# True when running in a container / WSL / otherwise lacking a real session
# bus for a graphical install. Works on minimal images without systemd.
is_container() {
  [[ -n ${container:-} ]] && return 0
  [[ -f /.dockerenv || -f /run/.containerenv ]] && return 0
  if command -v systemd-detect-virt >/dev/null 2>&1; then
    systemd-detect-virt --quiet --container 2>/dev/null && return 0
  fi
  # WSL has no real hardware/session either.
  grep -qiE "microsoft|wsl" /proc/version 2>/dev/null && return 0
  return 1
}

# True when virtualized (container OR VM) — firmware/driver packages are
# pointless there.
is_virtual() {
  is_container && return 0
  command -v systemd-detect-virt >/dev/null 2>&1 &&
    systemd-detect-virt --quiet 2>/dev/null && return 0
  return 1
}
