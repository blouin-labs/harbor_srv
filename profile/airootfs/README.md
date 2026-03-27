[← profile](../README.md)

<!-- vale Microsoft.Headings = NO -->
# airootfs/
<!-- vale Microsoft.Headings = YES -->

Configuration overlay copied verbatim into the root filesystem during `build-image.sh`. Every file here appears at the same path in the installed system. `profiledef.sh` sets permissions. See [`profile/README.md`](../README.md).

> The build strips this README from the image.

## Table of contents

- [Secure shell](#secure-shell)
- [Networking](#networking)
- [Network storage mount](#network-storage-mount)
- [Kerberos](#kerberos)
- [initramfs](#initramfs)
- [Runner](#runner)
- [Locale](#locale)
- [Credentials](#credentials)

---

## Secure shell

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

Overrides `systemd-networkd-wait-online` to pass `--any`, so any interface coming up satisfies `network-online.target` rather than waiting for all managed interfaces. Without this, Docker's virtual bridge interfaces can delay boot.

---

## Network storage mount

### [`etc/systemd/system/mnt-synology-harbor_srv.mount`](etc/systemd/system/mnt-synology-harbor_srv.mount)

Mounts the NAS share (`192.168.1.10:/volume1/harbor_srv`) at `/mnt/synology/harbor_srv` via NFSv4.1. Uses a soft mount with a 30-second timeout so a NAS outage doesn't hang the system. The `_netdev` flag tells systemd this mount requires the network and orders it correctly in the boot sequence. Enabled as a systemd unit so it starts automatically.

### [`etc/systemd/system/docker.service.d/nfs-dependency.conf`](etc/systemd/system/docker.service.d/nfs-dependency.conf)

Drop-in for `docker.service` that adds a hard dependency on the NAS mount. Prevents Docker from starting before the NFS share is available, which would cause any Compose stacks referencing NFS-backed volumes to fail on boot.

---

## Kerberos

The server runs a local MIT Kerberos Key Distribution Center (KDC) with realm `HARBOR.LOCAL`. Running the KDC on the server itself avoids a chicken-and-egg dependency: the KDC starts from local storage before the NFS mount, so Kerberos tickets are ready before the mount begins. The realm name `HARBOR.LOCAL` keeps this server-local realm separate from `jcb.local`, leaving that domain free for a future Docker-based KDC covering broader lab services. The eventual goal is `sec=krb5i` on the NFS mount (mutual auth + integrity). See issue blouin-labs/issues#43.

The KDC database and server keytab (`/etc/krb5.keytab`) are **secrets**. They're **not** present in this overlay—they're injected into the target partition by `harbor-deploy` at flash time from the `KRB5_SECRETS_B64` Actions secret. See `scripts/README.md` and the PR description for the one-time keytab generation steps.

### [`etc/krb5.conf`](etc/krb5.conf)

Kerberos client library configuration. Defines realm `HARBOR.LOCAL` with KDC and admin server both on `localhost`. DNS-based KDC discovery is off (`dns_lookup_kdc = false`) to prevent realm spoofing via a rogue DNS record. Ticket forwarding is off (`forwardable = false`) because NFS doesn't require delegation. Keeping it off limits the damage if an attacker compromises a service principal. Ticket lifetime is 24 hours, renewable for 7 days.

### [`var/lib/krb5kdc/kdc.conf`](var/lib/krb5kdc/kdc.conf)

KDC daemon configuration. The KDC listens on port 88 (UDP and TCP). The supported enctypes are `aes256-cts-hmac-sha1-96` and `aes128-cts-hmac-sha1-96` only. DES and RC4 are absent because both are cryptographically broken. The HMAC-SHA1-96 suffix identifies a message authentication code; SHA-1 isn't collision-sensitive in this role. These enctypes are the current Kerberos standard (RFC 3962). Maximum ticket life matches `krb5.conf` (24h/7d).

### [`var/lib/krb5kdc/kadm5.acl`](var/lib/krb5kdc/kadm5.acl)

kadmin access control list. Grants full administrative privileges (`*`) to any principal of the form `*/admin@HARBOR.LOCAL`. Used only for one-time keytab generation during setup. `kadmind` isn't running in production, so this ACL has no runtime effect. It exists so `kadmin.local` works correctly when run manually on the server.

### [`etc/systemd/system/rpc-gssd.service.d/krb5-ordering.conf`](etc/systemd/system/rpc-gssd.service.d/krb5-ordering.conf)

Drop-in that orders `rpc-gssd` after `krb5-kdc.service` and adds a hard dependency on it. Without this ordering, `rpc-gssd` could start before the local KDC is ready, causing GSS authentication failures on the NFS mount.

---

## initramfs

### [`etc/mkinitcpio.conf.d/archiso.conf`](etc/mkinitcpio.conf.d/archiso.conf)

Custom `mkinitcpio` hooks configuration. Specifies the minimal hook set needed to boot from an ext4 image on bare hardware: `base udev modconf block filesystems fsck no_emergency_shell`. `autodetect` is intentionally omitted—it scans `/sys` at build time, which in a CI container reflects the runner VM hardware, not the target ThinkPad. `linux.preset` (described earlier) references this file.

### [`etc/mkinitcpio.d/linux.preset`](etc/mkinitcpio.d/linux.preset)

mkinitcpio preset for the `linux` package. Defines a single `default` preset that points at the custom configuration described earlier. Replaces the stock preset so that running `mkinitcpio -P` (in `build-image.sh`) uses the project hooks rather than the package defaults.

### [`usr/lib/initcpio/install/no_emergency_shell`](usr/lib/initcpio/install/no_emergency_shell)

Build-time mkinitcpio hook. Bundles `blkid`, `sed`, and the runtime hook script into the initramfs image.

### [`usr/lib/initcpio/hooks/no_emergency_shell`](usr/lib/initcpio/hooks/no_emergency_shell)

Runtime `mkinitcpio` hook. Redefines `launch_interactive_shell` so that any initramfs-stage boot failure triggers automatic slot failover instead of an interactive emergency shell. An emergency shell would stall a headless server indefinitely.

On failure: reads the failing slot's PARTUUID from `/proc/cmdline`, loads `/new_root/etc/harbor/partitions.conf`, mounts the ESP, removes the failing slot's boot entries, flips `loader.conf` to the other slot, and reboots. If the partition configuration or ESP are unreachable, it falls back to a blind `sysrq` reboot (consuming one try-counter cycle).

---

## Runner

The GitHub Actions self-hosted runner runs as a dedicated `runner` user (UID 968)—never as root. The runner user is a member of the `docker` group so workflows can use Docker. The bootstrap script runs as root (to download and set up the NFS directory) but switches to the `runner` user for registration via `runuser`.

### [`usr/local/bin/harbor-runner-bootstrap`](usr/local/bin/harbor-runner-bootstrap)

One-shot script that downloads and registers the GitHub Actions self-hosted runner on first boot. Idempotent: if the runner is already registered (`.runner` exists on the NFS share), exits immediately. Otherwise downloads the latest runner release to the NFS share, sets ownership to `runner:runner`, and registers using the token file as the `runner` user.

Registration deletes the token file—it's single-use and shouldn't persist on the NFS share.

**First-time setup:** Before booting the image for the first time, place a GitHub Actions registration token at `/mnt/synology/harbor_srv/runner/token` on the NFS share. Generate one at: repository Settings → Actions → Runners → New self-hosted runner. The script deletes the token automatically after successful registration.

### [`etc/systemd/system/harbor-runner-bootstrap.service`](etc/systemd/system/harbor-runner-bootstrap.service)

Runs `harbor-runner-bootstrap` as a one-shot service after the NFS mount comes up. Uses `RemainAfterExit=yes` so the service stays active after the script exits, letting `harbor-runner.service` depend on it correctly.

### [`etc/systemd/system/harbor-runner.service`](etc/systemd/system/harbor-runner.service)

Runs the GitHub Actions runner (`run.sh` on the NFS share) as the `runner` user. Depends on the bootstrap service (runner must register first) and on the NFS mount via `BindsTo`, so the runner stops if the NFS mount goes away. The runner binary lives on NFS and survives A/B slot switches. It also self-updates when GitHub requires a newer version.

---

## Locale

### [`etc/locale.conf`](etc/locale.conf)

Sets the system locale to `C.UTF-8`, a minimal, dependency-free locale with full UTF-8 support. No locale data packages needed.

---

## Credentials

### [`etc/passwd`](etc/passwd)

System user database. Declares all users including package-created system accounts and the `runner` user (UID 968). This overlay replaces the `pacstrap`-generated file—when adding a package that creates a system user, add its entry here.

### [`etc/shadow`](etc/shadow)

Password database. Sets an empty root password. `sshd_config` turns off password authentication, so root login uses SSH key only. The `runner` user has a locked password (`!*`). Issue #13 tracks locking root's password too.

### [`etc/group`](etc/group)

System group database. Declares all groups including the `runner` group (GID 968). The `runner` user is a member of the `docker` group. Like `etc/passwd`, this overlay replaces the pacstrap-generated file.

### [`root/.ssh/authorized_keys`](root/.ssh/authorized_keys)

SSH public key authorized for root login. This is the only way to authenticate to the server remotely.
