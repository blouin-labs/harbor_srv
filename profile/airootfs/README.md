# airootfs/

Config overlay copied verbatim into the root filesystem during `build-image.sh`. Every file here appears at the same path in the installed system. Permissions are set separately via `profiledef.sh` — see `profile/README.md`.

This README is stripped from the image at build time.

---

## SSH

### [`etc/ssh/sshd_config.d/10-archiso.conf`](etc/ssh/sshd_config.d/10-archiso.conf)

SSH daemon hardening. Disables password authentication and restricts root login to key-based only. Also sets `AuthorizedKeysCommand none` to suppress the default Arch behavior of running `userdbctl` for every auth attempt, which produces spurious log errors on a system without user databases.

---

## Networking

### [`etc/systemd/network/20-ethernet.network`](etc/systemd/network/20-ethernet.network)

Static IP assignment for all physical Ethernet interfaces. Sets the server's fixed LAN address (`192.168.1.5`), gateway, and upstream DNS resolvers. The `Kind=!*` match excludes virtual interfaces (bridges, VLANs, etc.) so Docker's network interfaces aren't affected.

### [`etc/systemd/networkd.conf.d/ipv6-privacy-extensions.conf`](etc/systemd/networkd.conf.d/ipv6-privacy-extensions.conf)

Enables IPv6 privacy extensions globally for all interfaces managed by networkd. Randomizes the IPv6 interface identifier to avoid stable hardware-derived addresses.

### [`etc/systemd/resolved.conf.d/archiso.conf`](etc/systemd/resolved.conf.d/archiso.conf)

Enables Multicast DNS (mDNS) in systemd-resolved for `.local` name resolution on the LAN. Note: issue #14 tracks disabling mDNS if it's not needed.

### [`etc/systemd/system/systemd-networkd-wait-online.service.d/wait-for-only-one-interface.conf`](etc/systemd/system/systemd-networkd-wait-online.service.d/wait-for-only-one-interface.conf)

Overrides `systemd-networkd-wait-online` to pass `--any`, so `network-online.target` is satisfied as soon as any interface comes up rather than waiting for all managed interfaces. Without this, Docker's virtual bridge interfaces can delay boot unnecessarily.

---

## NFS mount

### [`etc/systemd/system/mnt-synology-harbor_srv.mount`](etc/systemd/system/mnt-synology-harbor_srv.mount)

Mounts the Synology NAS share (`192.168.1.10:/volume1/harbor_srv`) at `/mnt/synology/harbor_srv` via NFSv4.1. Uses a soft mount with a 30-second timeout so a NAS outage doesn't hang the system. The `_netdev` flag tells systemd this mount requires the network and orders it correctly in the boot sequence. Enabled as a systemd unit so it starts automatically.

### [`etc/systemd/system/docker.service.d/nfs-dependency.conf`](etc/systemd/system/docker.service.d/nfs-dependency.conf)

Drop-in for `docker.service` that adds a hard dependency on the Synology NFS mount. Prevents Docker from starting before the NFS share is available, which would cause any Compose stacks referencing NFS-backed volumes to fail on boot.

---

## Initramfs

### [`etc/mkinitcpio.conf.d/archiso.conf`](etc/mkinitcpio.conf.d/archiso.conf)

Custom mkinitcpio hooks config. Specifies the minimal hook set needed to boot from an ext4 image on bare hardware: `base udev autodetect modconf block filesystems fsck`. This file is referenced by `linux.preset` below.

### [`etc/mkinitcpio.d/linux.preset`](etc/mkinitcpio.d/linux.preset)

mkinitcpio preset for the `linux` package. Defines a single `default` preset that points at our custom config above. Replaces the stock preset so that running `mkinitcpio -P` (in `build-image.sh`) uses our hooks rather than the package defaults.

---

## Locale

### [`etc/locale.conf`](etc/locale.conf)

Sets the system locale to `C.UTF-8` — a minimal, dependency-free locale with full UTF-8 support. No locale data packages needed.

---

## Credentials

### [`etc/shadow`](etc/shadow)

Sets an empty root password. The account is accessible only via SSH key authentication (password auth is disabled in `sshd_config`). Issue #13 tracks locking this with a proper locked password entry (`!` in the password field) to prevent local console logins.

### [`root/.ssh/authorized_keys`](root/.ssh/authorized_keys)

SSH public key authorized for root login. This is the only way to authenticate to the server remotely.
