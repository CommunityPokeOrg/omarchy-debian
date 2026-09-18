# shellcheck shell=bash
# apt helpers for omarchy-debian.
# Source this file; do not execute it.

if [[ -n ${OMARCHY_DEBIAN_APT_LOADED:-} ]]; then
  return 0
fi
OMARCHY_DEBIAN_APT_LOADED=1

omd_apt_updated=0

apt_update_once() {
  ((omd_apt_updated)) && return 0
  if [[ ${OMARCHY_DEBIAN_DRY_RUN:-0} == "1" ]]; then
    log "dry-run: apt-get update"
    omd_apt_updated=1
    return 0
  fi
  log "apt-get update"
  $SUDO env DEBIAN_FRONTEND=noninteractive apt-get update -y
  omd_apt_updated=1
}

# True when $1 has an installable candidate in the apt indexes. `apt-cache
# show` alone is not enough — a package can exist in indexes with no
# candidate for this release (e.g. removed from testing).
apt_available() {
  local cand
  cand=$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/{print $2; exit}')
  [[ -n $cand && $cand != "(none)" ]]
}

# First candidate from a `|`-separated list that apt knows about.
apt_first_available() {
  local IFS='|'
  local candidate
  for candidate in $1; do
    if apt_available "$candidate"; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

# Install packages; skips ones already installed (idempotent). Nonexistent
# packages abort apt entirely, so callers must resolve candidates first.
apt_install() {
  local pkgs=("$@")
  ((${#pkgs[@]})) || return 0
  if [[ ${OMARCHY_DEBIAN_DRY_RUN:-0} == "1" ]]; then
    log "dry-run: apt-get install ${pkgs[*]}"
    return 0
  fi
  apt_update_once
  log "apt-get install ${pkgs[*]}"
  $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${pkgs[@]}"
}
