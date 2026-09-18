#!/bin/bash
# Install `external:` entries from packages/base.map — tools Omarchy gets from
# Arch extras/AUR that Debian either lacks or packages too old. Each installer
# is idempotent and degrades to a logged warning, never a hard failure.

set -euo pipefail
source "$OMARCHY_DEBIAN_ROOT/lib/log.sh"
source "$OMARCHY_DEBIAN_ROOT/lib/detect.sh"
source "$OMARCHY_DEBIAN_ROOT/lib/apt.sh"
source "$OMARCHY_DEBIAN_ROOT/lib/map.sh"

detect_distro

DRY_RUN=${OMARCHY_DEBIAN_DRY_RUN:-0}
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

gh_latest_release_asset() { # <owner/repo> <asset-regex> -> download URL
  local repo="$1" pattern="$2"
  curl -fsSL "https://api.github.com/repos/$repo/releases/latest" |
    grep -oE "\"browser_download_url\": *\"[^\"]+\"" |
    cut -d'"' -f4 | grep -E "$pattern" | head -1
}

have() { command -v "$1" >/dev/null 2>&1; }

install_external_gum() {
  have gum && return 0
  apt_available gum && { apt_install gum; return; }
  if [[ $DRY_RUN == "1" ]]; then log "dry-run: install gum .deb"; return 0; fi
  local url
  url=$(gh_latest_release_asset "charmbracelet/gum" "amd64\.deb$") || true
  [[ -n $url ]] || { warn "gum: no .deb asset found"; return 1; }
  curl -fsSL "$url" -o /tmp/gum.deb && $SUDO apt-get install -y /tmp/gum.deb && rm -f /tmp/gum.deb
}

install_external_lazygit() {
  have lazygit && return 0
  apt_available lazygit && { apt_install lazygit; return; }
  if [[ $DRY_RUN == "1" ]]; then log "dry-run: install lazygit"; return 0; fi
  local url
  url=$(gh_latest_release_asset "jesseduffield/lazygit" "linux_x86_64\.tar\.gz$") || true
  [[ -n $url ]] || { warn "lazygit: no release asset found"; return 1; }
  curl -fsSL "$url" | tar -xz -C /tmp lazygit && install -m755 /tmp/lazygit "$BIN_DIR/lazygit"
}

install_external_lazydocker() {
  have lazydocker && return 0
  apt_available lazydocker && { apt_install lazydocker; return; }
  if [[ $DRY_RUN == "1" ]]; then log "dry-run: install lazydocker"; return 0; fi
  local url
  url=$(gh_latest_release_asset "jesseduffield/lazydocker" "Linux_x86_64\.tar\.gz$") || true
  [[ -n $url ]] || { warn "lazydocker: no release asset found"; return 1; }
  curl -fsSL "$url" | tar -xz -C /tmp lazydocker && install -m755 /tmp/lazydocker "$BIN_DIR/lazydocker"
}

install_external_mise() {
  have mise && return 0
  if [[ $DRY_RUN == "1" ]]; then log "dry-run: install mise via apt repo"; return 0; fi
  # Official mise apt repository (https://mise.jdx.dev/getting-started.html)
  local keyring=/etc/apt/keyrings/mise-archive-keyring.gpg
  if [[ ! -f $keyring ]]; then
    $SUDO install -dm755 /etc/apt/keyrings
    curl -fsSL https://mise.jdx.dev/gpg-key.pub | $SUDO gpg --dearmor -o "$keyring"
  fi
  echo "deb [signed-by=$keyring] https://mise.jdx.dev/deb stable main" |
    $SUDO tee /etc/apt/sources.list.d/mise.list >/dev/null
  apt_update_once
  apt_install mise
}

install_external_starship() {
  have starship && return 0
  if apt_available starship; then
    apt_install starship
    return
  fi
  if [[ $DRY_RUN == "1" ]]; then log "dry-run: starship via install script"; return 0; fi
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$BIN_DIR"
}

install_external_eza() {
  have eza && return 0
  apt_available eza && { apt_install eza; return; }
  warn "eza not in apt indexes; skipping (alias ls or use a newer release)"
}

install_external_fastfetch() {
  have fastfetch && return 0
  apt_available fastfetch && { apt_install fastfetch; return; }
  if [[ $DRY_RUN == "1" ]]; then log "dry-run: fastfetch .deb"; return 0; fi
  local url
  url=$(gh_latest_release_asset "fastfetch-cli/fastfetch" "linux-amd64\.deb$") || true
  if [[ -n $url ]]; then
    curl -fsSL "$url" -o /tmp/fastfetch.deb && $SUDO apt-get install -y /tmp/fastfetch.deb && rm -f /tmp/fastfetch.deb
  else
    warn "fastfetch: no .deb asset found"
  fi
}

install_external_obsidian() {
  have obsidian && return 0
  apt_available obsidian && { apt_install obsidian; return; }
  if [[ $DRY_RUN == "1" ]]; then log "dry-run: obsidian .deb"; return 0; fi
  local url
  url=$(gh_latest_release_asset "obsidianmd/obsidian-releases" "amd64\.deb$") || true
  [[ -n $url ]] || { warn "obsidian: no .deb asset found"; return 1; }
  curl -fsSL "$url" -o /tmp/obsidian.deb && $SUDO apt-get install -y /tmp/obsidian.deb && rm -f /tmp/obsidian.deb
}

install_external_nerd_fonts() {
  local dir="$HOME/.local/share/fonts/JetBrainsMonoNerd"
  [[ -d $dir ]] && return 0
  if [[ $DRY_RUN == "1" ]]; then log "dry-run: JetBrainsMono Nerd Font"; return 0; fi
  local url
  url=$(gh_latest_release_asset "ryanoasis/nerd-fonts" "JetBrainsMono\.tar\.xz$") || true
  [[ -n $url ]] || { warn "nerd-fonts: release asset not found"; return 1; }
  mkdir -p "$dir"
  curl -fsSL "$url" | tar -xJ -C "$dir"
  fc-cache -f "$dir" >/dev/null 2>&1 || true
}

install_external_xdg_terminal_exec() {
  have xdg-terminal-exec && return 0
  if [[ $DRY_RUN == "1" ]]; then log "dry-run: xdg-terminal-exec"; return 0; fi
  curl -fsSL "https://raw.githubusercontent.com/Vladimir-csp/xdg-terminal-exec/master/xdg-terminal-exec" \
    -o "$BIN_DIR/xdg-terminal-exec" && chmod +x "$BIN_DIR/xdg-terminal-exec"
}

install_external_dua_cli() {
  have dua && return 0
  apt_available dua-cli && { apt_install dua-cli; return; }
  if [[ $DRY_RUN == "1" ]]; then log "dry-run: dua-cli binary"; return 0; fi
  local url
  url=$(gh_latest_release_asset "Byron/dua-cli" "linux-unknown-linux-musl\.tar\.gz$|linux-x86_64.*\.tar\.gz$") || true
  [[ -n $url ]] || { warn "dua-cli: no release asset found"; return 1; }
  curl -fsSL "$url" | tar -xz -C /tmp &&
    install -m755 "$(find /tmp -name dua -type f | head -1)" "$BIN_DIR/dua"
}

install_external_tree-sitter() {
  have tree-sitter && return 0
  apt_available tree-sitter-cli && { apt_install tree-sitter-cli; return; }
  if [[ $DRY_RUN == "1" ]]; then log "dry-run: tree-sitter"; return 0; fi
  local url
  url=$(gh_latest_release_asset "tree-sitter/tree-sitter" "linux-x64\.gz$") || true
  if [[ -n $url ]]; then
    curl -fsSL "$url" | gunzip >"$BIN_DIR/tree-sitter" && chmod +x "$BIN_DIR/tree-sitter"
  else
    warn "tree-sitter: no release asset found"
  fi
}

install_external_usage() {
  have usage && return 0
  if have mise; then
    [[ $DRY_RUN == "1" ]] && { log "dry-run: mise use -g usage"; return 0; }
    mise use -g usage@latest || warn "usage: mise install failed"
  else
    warn "usage: needs mise; skipping"
  fi
}

# Run external installers for every external: id present in the maps.
collect_externals() {
  list_non_apt "$OMARCHY_DEBIAN_ROOT/packages/base.map"
  list_non_apt "$OMARCHY_DEBIAN_ROOT/packages/extra.map"
}

collect_externals | while IFS=$'\t' read -r _pkg strategy id _notes; do
  [[ $strategy == "external" ]] || continue
  fn="install_external_${id//-/_}"
  if declare -F "$fn" >/dev/null; then
    if ! "$fn"; then
      warn "external install failed: $id"
    fi
  else
    warn "external:$id has no installer ($fn)"
  fi
done

# Fallback installers for apt-any entries that are missing on older releases
# (they no-op when the apt package was already installed).
for fb in eza starship fastfetch tree-sitter dua_cli; do
  install_external_"$fb" || true
done
