#!/bin/bash
# Final report: what was installed, what needs a human.

set -euo pipefail
source "$OMARCHY_DEBIAN_ROOT/lib/log.sh"
source "$OMARCHY_DEBIAN_ROOT/lib/map.sh"
source "$OMARCHY_DEBIAN_ROOT/lib/detect.sh"

detect_distro

echo
log "==================== summary ===================="

if [[ ${OMARCHY_DEBIAN_DRY_RUN:-0} == "1" ]]; then
  log "this was a dry run — nothing was installed"
fi

manual_items() {
  list_non_apt "$OMARCHY_DEBIAN_ROOT/packages/base.map"
  list_non_apt "$OMARCHY_DEBIAN_ROOT/packages/extra.map"
}

manual_items | while IFS=$'\t' read -r pkg strategy arg notes; do
  case "$strategy" in
    manual)
      echo "  MANUAL  $pkg — ${notes:-$arg}"
      ;;
    skip)
      echo "  SKIP    $pkg — ${notes:-$arg}"
      ;;
  esac
done | sort -u >>"$OMARCHY_DEBIAN_LOG_FILE" 2>/dev/null || true

echo
echo "Next steps:"
echo "  1. Reboot (or log out/in) so the session and group changes take effect."
echo "  2. At the SDDM greeter pick the 'Omarchy' session, or run 'Hyprland'/'sway' from a TTY."
echo "  3. Read docs/MANUAL-STEPS.md for anything marked MANUAL above and in:"
echo "       $OMARCHY_DEBIAN_LOG_FILE"
echo "  4. Known gaps are documented in docs/LIMITATIONS.md"
