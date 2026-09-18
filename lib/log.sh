# shellcheck shell=bash
# Logging helpers shared by all omarchy-debian install phases.
# Source this file; do not execute it.

if [[ -n ${OMARCHY_DEBIAN_LOG_LOADED:-} ]]; then
  return 0
fi
OMARCHY_DEBIAN_LOG_LOADED=1

: "${OMARCHY_DEBIAN_LOG_FILE:=${HOME}/.local/state/omarchy-debian/install.log}"

omd_log_file_ready=0
omd_ensure_log_file() {
  ((omd_log_file_ready)) && return 0
  mkdir -p "$(dirname "$OMARCHY_DEBIAN_LOG_FILE")" 2>/dev/null || return 0
  touch "$OMARCHY_DEBIAN_LOG_FILE" 2>/dev/null && omd_log_file_ready=1
}

log() {
  local line
  line="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "$line"
  if omd_ensure_log_file; then
    echo "$line" >>"$OMARCHY_DEBIAN_LOG_FILE" 2>/dev/null || true
  fi
}

warn() { log "WARN: $*" >&2; }
err() { log "ERROR: $*" >&2; }
die() {
  err "$*"
  exit 1
}

# Run a phase script with logging; a failing phase is reported but (unless
# OMARCHY_DEBIAN_STRICT=1) does not abort the whole install. Returns the
# phase's exit status.
run_phase() {
  local script="$1"
  shift || true
  [[ -f $script ]] || die "install phase missing: $script"
  log "=== phase: ${script##*/} ==="
  local status=0
  if [[ ${OMARCHY_DEBIAN_DRY_RUN:-0} == "1" ]]; then
    OMARCHY_DEBIAN_DRY_RUN=1 bash "$script" "$@" || status=$?
  else
    bash "$script" "$@" || status=$?
  fi
  if ((status != 0)); then
    warn "phase ${script##*/} exited with status $status"
    ((OMARCHY_DEBIAN_STRICT)) && exit "$status"
  fi
  log "=== done: ${script##*/} (status $status) ==="
  return "$status"
}
