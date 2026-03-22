# scripts/

Operational scripts for building, installing, and deploying harbor_srv.

## `build-image.sh`

Builds a root filesystem image from the profile directory. Run by CI on every push.

```bash
sudo ./scripts/build-image.sh [profile_dir] [output_dir]
# defaults: profile_dir=profile, output_dir=output
```

**What it does:**

1. Creates a 4GB raw ext4 image
2. Mounts it via loopback
3. Runs `pacstrap` to install all packages from `profile/packages.x86_64`
4. Copies `profile/airootfs/` overlay verbatim into the image
5. Applies file permissions from `profile/profiledef.sh`
6. Sets hostname, generates locale, enables systemd services
7. Generates initramfs with `mkinitcpio -P`
8. Compresses with `zstd -T0 -10` and writes a SHA256 checksum

**Output:** `output/harbor_srv-root.img.zst` + `output/harbor_srv-root.img.zst.sha256`

The mkinitcpio pacman hook is suppressed during `pacstrap` and run manually after the overlay is in place. This ensures the initramfs is built with the correct hooks and preset from the profile rather than defaults.

## `install.sh`

One-time installer. Run from a live Arch ISO or rescue environment to partition a fresh NVMe and write the first image.

```bash
sudo ./scripts/install.sh /dev/nvme0n1 harbor_srv-root.img.zst
```

**What it does:**

1. Partitions the disk with the A/B layout (prompts for confirmation — destructive)
2. Formats all four partitions
3. Writes the image to Root A and resizes the filesystem to fill the partition
4. Installs systemd-boot to the ESP
5. Creates boot entries for Root A and Root B
6. Copies kernel and initramfs to the ESP
7. Writes `/etc/fstab` in the new root
8. Writes `/etc/harbor/partitions.conf` with PARTUUIDs for `deploy.sh` to use

**Partition layout:**

| Partition | Size | Label | Filesystem |
|-----------|------|-------|------------|
| p1 | 512M | ESP | FAT32 |
| p2 | 10G | Root A | ext4 |
| p3 | 10G | Root B | ext4 |
| p4 | remainder | Data | ext4 |

After installation, disable Secure Boot in the UEFI firmware (the bootloader is unsigned) and reboot.

## `deploy.sh`

Deploys a new root image to the inactive A/B partition. Run on the live server as root.

```bash
sudo ./scripts/deploy.sh /tmp/harbor_srv-root.img.zst
```

**What it does:**

1. Reads `/etc/harbor/partitions.conf` to get partition device paths and PARTUUIDs
2. Detects the active root partition via `findmnt`
3. Selects the other (inactive) partition as the target
4. Decompresses and writes the image to the target partition
5. Resizes the filesystem to fill the partition
6. Mounts the new root, writes `/etc/fstab`, and copies `partitions.conf`
7. Copies the kernel and initramfs to the ESP
8. Writes a boot entry with a 3-try counter (`harbor-a+3.conf` or `harbor-b+3.conf`)
9. Sets the boot default via glob (`harbor-a*` or `harbor-b*`) in `loader.conf`
10. Reboots after a 5-second grace period

**A/B fallback mechanism:**

Boot entries use systemd-boot's try-counter convention. The filename `harbor-b+3.conf` tells systemd-boot to try booting this entry up to 3 times. On each failed boot attempt, the counter decrements (`+3` → `+2` → `+1`). When it reaches zero, systemd-boot skips the entry and falls back to the previously working partition.

On successful boot, `systemd-bless-boot.service` renames the file to the blessed form (`harbor-b.conf`), locking in the new root.

The glob default (`harbor-b*`) matches both the counted form (`harbor-b+3.conf`) and the blessed form (`harbor-b.conf`), so no update to `loader.conf` is needed after blessing.

**Typical deploy workflow:**

```bash
# Download the latest artifact
gh run download <run-id> -n harbor_srv-root -D /tmp/deploy

# Transfer to server
scp /tmp/deploy/harbor_srv-root.img.zst root@192.168.1.5:/tmp/
scp scripts/deploy.sh root@192.168.1.5:/tmp/

# Run deploy
ssh root@192.168.1.5 "bash /tmp/deploy.sh /tmp/harbor_srv-root.img.zst"
```
