# shellcheck shell=bash
# Package-map engine: reads packages/*.map and resolves each upstream
# Arch/AUR package to a Debian strategy.
#
# Map format (TSV, one package per line, '#' comments allowed):
#   arch_pkg<TAB>strategy<TAB>argument<TAB>notes
#
# Strategies:
#   apt:<pkg>              single Debian package name, always installed
#   apt-any:<a>|<b>|<c>    first candidate present in the apt indexes
#   apt-hw:<a>|<b>|<c>     like apt-any but only when matching hardware is
#                          detected (install/45-hardware.sh)
#   external:<id>          handled by an install_external_<id>() function in
#                          install/20-external.sh
#   manual:<note>          cannot be automated; surfaced in the final report
#   skip:<reason>          Arch/pacman/AUR-only, intentionally not ported

if [[ -n ${OMARCHY_DEBIAN_MAP_LOADED:-} ]]; then
  return 0
fi
OMARCHY_DEBIAN_MAP_LOADED=1

# iterate_map <file> <callback> — callback receives: pkg strategy arg notes
iterate_map() {
  local file="$1" callback="$2"
  local pkg strategy arg notes
  while IFS=$'\t' read -r pkg strategy arg notes; do
    [[ -z $pkg || $pkg == \#* ]] && continue
    "$callback" "$pkg" "$strategy" "$arg" "$notes"
  done <"$file"
}

# Collect apt package names a map resolves to, printing one per line.
# Items that fail to resolve are printed to stderr prefixed with "!".
resolve_apt_packages() {
  local file="$1"
  iterate_map "$file" _resolve_one
}

_resolve_one() {
  local pkg="$1" strategy="$2" arg="$3" notes="${4:-}"
  local resolved
  case "$strategy" in
    apt)
      if apt_available "$arg"; then
        echo "$arg"
      else
        echo "! $pkg -> $arg (not in apt indexes)" >&2
      fi
      ;;
    apt-any)
      if resolved=$(apt_first_available "$arg"); then
        echo "$resolved"
      else
        echo "! $pkg -> none of [$arg] available" >&2
      fi
      ;;
    apt-hw | external | manual | skip) : ;; # not handled by apt
    *) echo "! $pkg: unknown strategy '$strategy'" >&2 ;;
  esac
}

# Lists every non-apt entry as: pkg<TAB>strategy<TAB>arg<TAB>notes
list_non_apt() {
  local file="$1"
  iterate_map "$file" _list_non_apt_one
}

_list_non_apt_one() {
  local pkg="$1" strategy="$2" arg="$3" notes="${4:-}"
  case "$strategy" in
    apt-hw | external | manual | skip)
      printf '%s\t%s\t%s\t%s\n' "$pkg" "$strategy" "$arg" "$notes"
      ;;
  esac
}

# Lists every apt-hw entry as: pkg<TAB>candidates<TAB>notes
list_hw_packages() {
  local file="$1"
  iterate_map "$file" _list_hw_one
}

_list_hw_one() {
  local pkg="$1" strategy="$2" arg="$3" notes="${4:-}"
  [[ $strategy == "apt-hw" ]] && printf '%s\t%s\t%s\n' "$pkg" "$arg" "$notes"
}
