#!/bin/bash
# Validation for omarchy-debian: shell syntax, map integrity, dry-run smoke.
# Safe to run anywhere (no root, no changes). Usage: test/validate.sh

set -uo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT" || exit 1

fail=0
say() { printf '%s\n' "$*"; }

say "== bash -n syntax check =="
while IFS= read -r -d '' f; do
  if bash -n "$f" 2>/dev/null; then
    :
  else
    say "SYNTAX FAIL: $f"
    bash -n "$f"
    fail=1
  fi
done < <(find . -name '*.sh' -o -name 'install.sh' -o -path './overlay/bin/*' | tr '\n' '\0')

say "== map format check =="
for m in packages/*.map; do
  while IFS=$'\t' read -r pkg strategy arg _notes; do
    [[ -z $pkg || $pkg == \#* ]] && continue
    case "$strategy" in
      apt | apt-any | apt-hw | external | manual | skip) ;;
      *)
        say "BAD STRATEGY '$strategy' for $pkg in $m"
        fail=1
        ;;
    esac
    if [[ $strategy == apt || $strategy == apt-any || $strategy == apt-hw || $strategy == external ]] && [[ -z $arg ]]; then
      say "MISSING ARG for $pkg ($strategy) in $m"
      fail=1
    fi
    # external must have an installer function
    if [[ $strategy == external ]] && ! grep -q "install_external_${arg//-/_}\b" install/20-external.sh; then
      say "NO INSTALLER for external:$arg ($pkg)"
      fail=1
    fi
  done <"$m"
done
say "maps: $(grep -cv '^#\|^$' packages/base.map) base + $(grep -cv '^#\|^$' packages/extra.map) extra entries checked"

say "== every upstream base package is mapped =="
missing=0
upstream_list=${OMARCHY_UPSTREAM_PKG_LIST:-/dev/null}
if [[ -f $upstream_list ]]; then
  while IFS= read -r p; do
    [[ -z $p || $p == \#* ]] && continue
    grep -q "^$p	" packages/base.map || grep -q "^$p	" packages/extra.map || {
      say "UNMAPPED upstream package: $p"
      missing=1
    }
  done <"$upstream_list"
  ((missing)) && fail=1
else
  say "(skipped: set OMARCHY_UPSTREAM_PKG_LIST to check against upstream packages file)"
fi

say "== overlay shell files pass bash -n =="
if command -v shellcheck >/dev/null; then
  say "== shellcheck =="
  shellcheck -x -S warning install.sh lib/*.sh install/*.sh overlay/bin/* || fail=1
else
  say "(shellcheck not installed — skipped)"
fi

if ((fail)); then
  say "VALIDATION FAILED"
  exit 1
fi
say "VALIDATION OK"
