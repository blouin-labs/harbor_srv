[← harbor_srv](../README.md)

<!-- vale Microsoft.Headings = NO -->
# profile/
<!-- vale Microsoft.Headings = YES -->

The OS profile—everything baked into the root filesystem image.

## Table of contents

- [Files](#files)
  - [packages.x86_64](#packagesx86_64)
  - [pacman.conf](#pacmanconf)
  - [profiledef.sh](#profiledefsh)
- [airootfs/](#airootfs)
- [Making changes](#making-changes)

`scripts/build-image.sh` reads this directory to produce `harbor_srv-root.img.zst`.

## Files

### `packages.x86_64`

Package list installed via `pacstrap`. One package per line. Lines starting with `#` are comments.

Current packages:

| Package | Purpose |
|---------|---------|
| `base`, `linux`, `linux-firmware`, `mkinitcpio` | Base Arch Linux system |
| `openssh` | SSH daemon |
| `pv` | Progress display for pipes |
| `efibootmgr` | EFI boot entry management |
| `docker`, `docker-compose` | Container runtime |
| `nfs-utils` | NFS client (Synology mount) |

### `pacman.conf`

pacman configuration used during the build. Passed to `pacstrap -C` so the build uses the same mirrors and settings as a production system.

### `profiledef.sh`

File permission overrides applied after copying the `airootfs` overlay. `cp -a` preserves permissions from the repository, but some paths need specific modes that differ from what git stores.

```bash
file_permissions=(
  ["/"]="0:0:755"               # root-owned, world-readable
  ["/etc/shadow"]="0:0:400"     # root read-only
  ["/root"]="0:0:700"           # required by SSH StrictModes
  ["/root/.ssh"]="0:0:700"      # required by SSH StrictModes
  ["/root/.ssh/authorized_keys"]="0:0:600"
)
```

The `/root` and `/root/.ssh` entries are critical. Without them, `sshd` refuses key authentication because StrictModes checks that the home directory isn't world-readable.

## `airootfs/`

Configuration overlay copied verbatim into the root filesystem (`cp -a airootfs/. mnt/`). Paths here map directly to their location in the installed system. The build strips README files inside `airootfs/` from the image.

See [`airootfs/README.md`](airootfs/README.md) for documentation of every configuration file.

## Making changes

- **Add a package**: add it to `packages.x86_64`
- **Add or modify a configuration file**: add it under `airootfs/` at the path it should appear on the root filesystem
- **Fix file permissions**: add the path to `profiledef.sh`

Push to a branch, open a PR. CI builds and uploads the artifact. Merge and deploy.
