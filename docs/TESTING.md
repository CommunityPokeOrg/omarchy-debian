# Testing / validation

## Static validation (no system changes)

```bash
./test/validate.sh
```

Checks: `bash -n` on every script, map format/strategy sanity, every
`external:` id has an installer function, and — when
`OMARCHY_UPSTREAM_PKG_LIST` points at upstream's `omarchy-base.packages` —
full coverage of the upstream package list:

```bash
git clone --depth 1 https://github.com/omacom/omarchy /tmp/omarchy
OMARCHY_UPSTREAM_PKG_LIST=/tmp/omarchy/install/omarchy-base.packages ./test/validate.sh
```

## Dry-run on a live system

```bash
./install.sh --dry-run
```

Resolves all mappings against your apt indexes and logs what would be
installed — nothing is changed.

## Container smoke test (full installer)

```bash
docker run --rm -v "$PWD:/omarchy-debian" -w /omarchy-debian \
  debian:trixie bash -c '
    apt-get update -qq && apt-get install -y -qq sudo git curl >/dev/null &&
    ./install.sh --yes --dry-run && echo DRY-RUN-OK'
```

or for a real (container-scoped) package install:

```bash
docker run --rm -v "$PWD:/omarchy-debian" -w /omarchy-debian \
  debian:trixie bash -c '
    apt-get update -qq && apt-get install -y -qq sudo git curl >/dev/null &&
    OMARCHY_DEBIAN_STRICT=0 ./install.sh --yes --no-desktop --phases 00-preflight.sh,10-apt-deps.sh &&
    echo APT-PHASE-OK'
```

(Service/compositor phases detect the container and skip automatically.)

## Manual acceptance check

On a real Debian 13 / Ubuntu 24.10+ machine:

1. `./install.sh --yes` completes without failed phases.
2. `reboot` → SDDM greeter shows an **Omarchy (Debian)** session.
3. In the session: `SUPER+Return` opens a terminal, `SUPER+Space` opens fuzzel,
   `Print` screenshots to `~/Pictures/Screenshots`.
4. `omarchy-pkg-install` opens the apt-based fuzzy picker; `omarchy update`
   runs an apt upgrade.
5. `echo $OMARCHY_PATH` → `~/.local/share/omarchy` and `omarchy --help` lists
   the upstream command router.
