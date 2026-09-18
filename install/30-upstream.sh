#!/bin/bash
# Fetch the upstream omarchy repo read-only at a pinned commit and place it at
# $OMARCHY_PATH (default ~/.local/share/omarchy). Upstream is never modified;
# Debian-specific files live in this repo's overlay/.

set -euo pipefail
source "$OMARCHY_DEBIAN_ROOT/lib/log.sh"

# Pinned upstream ref (omacom/omarchy). Bump OMARCHY_UPSTREAM_REF to track newer.
: "${OMARCHY_UPSTREAM_REPO:=https://github.com/omacom/omarchy.git}"
: "${OMARCHY_UPSTREAM_REF:=9c5482c58dbe4974de337450754885083c91eada}"
: "${OMARCHY_PATH:=$HOME/.local/share/omarchy}"
export OMARCHY_UPSTREAM_REPO OMARCHY_UPSTREAM_REF OMARCHY_PATH

if [[ ${OMARCHY_DEBIAN_DRY_RUN:-0} == "1" ]]; then
  log "dry-run: clone $OMARCHY_UPSTREAM_REPO@$OMARCHY_UPSTREAM_REF -> $OMARCHY_PATH"
  exit 0
fi

if [[ ! -d $OMARCHY_PATH/.git ]]; then
  log "cloning upstream omarchy -> $OMARCHY_PATH"
  mkdir -p "$(dirname "$OMARCHY_PATH")"
  git clone --quiet "$OMARCHY_UPSTREAM_REPO" "$OMARCHY_PATH"
fi

cd "$OMARCHY_PATH"
if [[ $(git rev-parse HEAD) != "$OMARCHY_UPSTREAM_REF" ]]; then
  log "checking out pinned ref $OMARCHY_UPSTREAM_REF"
  git fetch --quiet --depth 1 origin "$OMARCHY_UPSTREAM_REF" || git fetch --quiet origin
  git checkout --quiet "$OMARCHY_UPSTREAM_REF"
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  warn "$OMARCHY_PATH has local modifications — upstream tree must stay pristine."
  warn "Stash or revert them; overlays belong in $OMARCHY_DEBIAN_ROOT/overlay."
fi

log "upstream omarchy at $(git rev-parse --short HEAD)"
