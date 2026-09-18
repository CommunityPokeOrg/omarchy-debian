# Limitations

What does **not** port from Arch/Omarchy, and why.

## The Omarchy shell (bar, launcher, menus, notifications)

The upstream desktop UI under `shell/` is a **Quickshell** application.
Quickshell is not packaged for Debian or Ubuntu, so the Omarchy bar, launcher
(`omarchy-menu`), notifications panel, and the shell-driven theme system do not
run without building Quickshell — and a recent Hyprland — from source.

The overlay therefore ships a **waybar + fuzzel + mako** substitute so the
session is usable out of the box. Building Quickshell manually restores more of
the upstream experience but is untested in this port.

## Hyprland version gap

Upstream Omarchy configures Hyprland through its **Lua API** (`config/hypr/*.lua`,
`default/hypr/`), which requires a recent Hyprland built with Lua support.

- Debian 13 (trixie) carries Hyprland only in **trixie-backports** (0.55+,
  which does include Lua support); the installer enables backports and
  installs from there.
- Ubuntu 24.10+ ships Hyprland in universe; Ubuntu 24.04 LTS and Debian 12
  ship **no Hyprland at all**.

The overlay ships `overlay/config/hypr/hyprland.conf`, a functional
classic-syntax port of the core bindings/look — it works on every packaged
version and ignores nothing the user edits. On backports/newer Hyprland you
may instead copy upstream's `config/hypr/*.lua` tree from
`~/.local/share/omarchy` into `~/.config/hypr/` and delete the `.conf` file.
Upstream Lua-only features (workspace-layouts, qconsole, toggles, per-app
window rules) are untested on this port.

## Omarchy/AUR packages with no Debian equivalent

Skipped entirely: `aether` (lockscreen), `herdr` (job daemon), `omacalc`,
`omacut`, `omawrite` (web apps), `cliamp`, `tensaku`, `ttfx`, `tobi-try`,
`hyprland-preview-share-picker`, `hyprland-guiutils`, `omarchy-nvim` (nvim
config lives in `omacom/omarchy-pkgs`), `expac`, `pacman-contrib`, `yay`,
`kernel-modules-hook`, `ufw-docker` (manual script exists).

## Boot & snapshot stack

- **Limine** bootloader → Debian keeps GRUB/systemd-boot. Omarchy's
  limine-entry-tool / snapper boot-snapshot integration is not ported.
- **mkinitcpio** → Debian uses initramfs-tools; no equivalent hooks needed.
- **linux-omarchy kernel** → stock Debian kernel.
- **Snapper** works on Debian if root is btrfs, but the bootable-snapshot
  pipeline does not exist; snapper is installed but unconfigured.
- **Plymouth** splash theme is not deployed (upstream theme expects the limine
  boot flow).

## Hardware-specific fixes

Upstream `install/hardware/` covers Apple T2 Macs, Surface, Framework 16, ASUS
ROG, Dell XPS quirks, TUXEDO laptops, etc. Only generic firmware/NVIDIA/Intel
detection is ported (`install/45-hardware.sh`). Vendor-specific items are
`manual:` in `packages/extra.map` with pointers to their projects.

## Browser on Ubuntu

Ubuntu's `chromium` apt package is a **snap transitional stub**. On Ubuntu the
installer still installs it (snap will be pulled in if snapd is present), but
if you avoid snap, install Firefox (`firefox` deb via the mozillateam PPA) or
the upstream `.deb` and set it as default. On Debian proper `chromium` is a
real deb.

## Chromium extensions / native messaging

Upstream ships custom Chromium extensions + native-messaging hosts under
`default/chromium/`. The dotfiles phase does not deploy these — they assume
`omarchy-*` helper binaries that are only partially ported.

## Services and assumptions

- The omarchy **provisioning/first-boot** flow (provisioning service, factory
  reset) does not exist; this repo configures an existing system.
- `ufw-docker` integration is not automated (upstream's trick relies on the
  ISO firewall sharing; run it manually after ufw is active).
- The sddm theme shipped upstream needs Qt6 SDDM; the overlay keeps the
  distro `breeze` theme.
- Many upstream `bin/omarchy-*` commands are distro-agnostic and work, but any
  touching pacman/AUR/limine/snapper will fail or no-op. The overlay shadows
  the package-management ones (`omarchy-pkg-*`, `omarchy-update-*`) with apt
  equivalents — overlay/bin precedes upstream/bin on PATH.

## Not tested

- NVIDIA proprietary driver under Hyprland (uwsm session should work; legacy
  `nvidia_drm.modeset=1` kernel parameter may still be needed).
- Secure Boot.
- Apple T2 / Surface / Framework-specific fixes.
