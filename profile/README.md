# profile/

The OS profile — everything baked into the root filesystem image.

`scripts/build-image.sh` reads this directory to produce `harbor_srv-root.img.zst`.

## Files

### `packages.x86_64`

Package list installed via `pacstrap`. One package per line; lines starting with `#` are comments.

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

File permission overrides applied after the `airootfs` overlay is copied. `cp -a` preserves permissions from the repo, but some paths need specific modes that differ from what git stores.

```bash
file_permissions=(
  ["/"]="0:0:755"               # root-owned, world-readable
  ["/etc/shadow"]="0:0:400"     # root read-only
  ["/root"]="0:0:700"           # required by SSH StrictModes
  ["/root/.ssh"]="0:0:700"      # required by SSH StrictModes
  ["/root/.ssh/authorized_keys"]="0:0:600"
)
```

The `/root` and `/root/.ssh` entries are critical. Without them, `sshd` refuses key authentication because StrictModes checks that the home directory is not world-accessible.

## `airootfs/`

Config overlay copied verbatim into the root filesystem (`cp -a airootfs/. mnt/`). Paths here map directly to their location in the installed system.

### Notable files

**`etc/systemd/network/20-ethernet.network`** — Static IP configuration.

```ini
[Network]
Address=192.168.1.5/24
Gateway=192.168.1.1
DNS=1.1.1.1
DNS=8.8.8.8
```

Matches all physical Ethernet interfaces (`Type=ether`, `Kind=!*`).

**`etc/systemd/system/mnt-synology-harbor_srv.mount`** — NFS mount for the Synology share. Enabled in `build-image.sh`. Uses `soft` mount with a 30-second timeout so a NAS outage doesn't hang the system indefinitely.

**`etc/systemd/system/docker.service.d/nfs-dependency.conf`** — Makes Docker wait for the NFS mount before starting, so Compose stacks that reference NFS paths don't fail on boot.

**`etc/ssh/sshd_config.d/10-archiso.conf`** — SSH hardening:

```
PasswordAuthentication no
PermitRootLogin prohibit-password
AuthorizedKeysCommand none
```

`AuthorizedKeysCommand none` overrides the default Arch sshd config that runs `userdbctl` for every auth attempt. That default causes spurious log errors and is unnecessary here.

**`etc/mkinitcpio.conf.d/archiso.conf`** and **`etc/mkinitcpio.d/linux.preset`** — Custom initramfs hooks and preset. Ensures the initramfs built during `build-image.sh` uses the correct hooks for booting from an ext4 image.

**`root/.ssh/authorized_keys`** — SSH public key for root login. This is the only authentication method.

## Making changes

- **Add a package**: add it to `packages.x86_64`
- **Add or modify a config file**: add it under `airootfs/` at the path it should appear on the root filesystem
- **Fix file permissions**: add the path to `profiledef.sh`

Push to a branch, open a PR. CI builds and uploads the artifact. Merge and deploy.
