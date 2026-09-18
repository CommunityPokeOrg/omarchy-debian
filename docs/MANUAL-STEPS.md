# Manual steps

Things the installer cannot or will not do for you, grouped by theme.

## Compositor

### Hyprland on Debian 12 / Ubuntu 24.04
Neither release packages Hyprland. Options:

1. **Upgrade the OS** — Debian 13 (trixie) and Ubuntu 24.10+ ship `hyprland`
   in the archive; the installer picks it up automatically.
2. **Build from source** — follow https://wiki.hypr.land/Getting-Started/Installation/
   ("Manual Build"). You also want `hyprland-guiutils`, `aquamarine`,
   `hyprlang`, `hyprcursor`, `hyprgraphics`, `hyprwire`, `hyprutils`,
   `hyprwayland-scanner`, and `xdg-desktop-portal-hyprland` — all from the
   hyprwm org. Build newest-first (utils → lang → cursor → graphics →
   aquamarine → hyprland).
3. **Use the Sway fallback** — `--compositor sway`, or just let auto-detection
   pick it. You lose the Hyprland-only features but keep the tiling workflow.

### The real Omarchy shell (quickshell)
The upstream bar/launcher needs Quickshell (git main builds against very new
Qt6). Rough recipe on trixie:

```bash
sudo apt install qt6-base-dev qt6-declarative-dev qt6-wayland-dev \
  libqt6svg6-dev cmake ninja-build libjemalloc-dev libpipewire-0.3-dev \
  libpam0g-dev libdrm-dev libgbm-dev libxcb1-dev libcli11-dev
git clone https://github.com/quickshell-mirror/quickshell
cmake -B quickshell/build -S quickshell -GNinja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo -DDISTRIBUTOR=omarchy-debian
cmake --build quickshell/build && sudo cmake --install quickshell/build
```

Then the upstream shell can run via `quickshell -c omarchy` once its
`shell/` tree is linked. **Untested**; expect Qt6 version gaps.

## Fonts

- `ttf-ia-writer` (iA Writer Mono/Duo/Quattro): proprietary; the AUR package
  downloads from a fixed URL. Manual: download the fonts and drop them into
  `~/.local/share/fonts`, then `fc-cache -f`.
- JetBrains Mono Nerd Font is auto-installed (`external:nerd-fonts`).

## Apps with upstream installers

- **gpu-screen-recorder**: `flatpak install com.dec05eba.gpu_screen_recorder`
  or https://git.dec05eba.com/gpu-screen-recorder
- **mpv-mpris**: build https://github.com/hoyon/mpv-mpris
- **localsend** on releases without the deb: `flatpak install org.localsend.localsend_app`
- **ufw-docker**: after `ufw` is active —
  `git clone https://github.com/chaifeng/ufw-docker && sudo ./ufw-docker/install` —
  then `sudo systemctl restart ufw`
- **omarchy-nvim**: the Neovim distribution lives in
  `omacom/omarchy-pkgs/pkgbuilds/omarchy-nvim`; copy its config payload into
  `~/.config/nvim`.
- **tzupdate**: `sudo timedatectl set-timezone <zone>` or use `tzupdate` from
  pipx (`pipx install tzupdate`).
- **ytt/dia/misc TUIs** marked `manual:` in packages/*.map: install upstream.

## Docker

Distro `docker.io` is installed. If you prefer upstream Docker CE:
https://docs.docker.com/engine/install/debian/ — then adapt `packages/base.map`.

Upstream deliberately does **not** add you to the `docker` group (it's
root-equivalent). Use `sudo docker …` or a polkit rule.

## Security / login

- **Fingerprint / FIDO2**: upstream has `setup-fingerprint`/`setup-agent`
  first-run hooks. On Debian install `fprintd` + `libpam-fprintd` and run
  `fprintd-enroll`.
- **Hibernation**: needs swap config + `resume=` kernel param; see
  `man systemd-hibernate.service` and your initramfs hooks.

## Snapshots (snapper)

If `/` is btrfs, `snapper` is installed but unconfigured:

```bash
sudo snapper -c root create-config /
sudo snapper -c root set-config TIMELINE_CREATE=yes
```

Bootable snapshots like upstream's limine-snapper-sync are **not** ported.

## Setting the default terminal / editor

`xdg-terminal-exec` reads `~/.config/xdg-terminals.list`. Put e.g. `foot.desktop`
or `org.gnome.Terminal.desktop` first. `EDITOR` is set in
`~/.config/uwsm/env.d/` and your `~/.bashrc` omarchy block.
