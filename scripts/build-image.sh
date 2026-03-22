#!/usr/bin/env bash
#
# build-image.sh — Build a root filesystem image for harbor_srv
#
# Creates a raw ext4 image containing a full Arch Linux install with all
# packages and configs from the profile directory. This replaces mkarchiso
# for the image-based deployment model (issue #20).
#
# Usage: sudo ./scripts/build-image.sh [profile_dir] [output_dir]
#
set -euo pipefail

PROFILE_DIR="${1:-profile}"
OUTPUT_DIR="${2:-output}"
WORK_DIR="${TMPDIR:-/tmp}/harbor-build-$$"
IMAGE_NAME="harbor_srv-root.img"
ROOT_SIZE="4G"

cleanup() {
    echo ":: Cleaning up..."
    if mountpoint -q "${WORK_DIR}/mnt" 2>/dev/null; then
        umount -R "${WORK_DIR}/mnt"
    fi
    if [ -n "${LOOP_DEV:-}" ]; then
        losetup -d "$LOOP_DEV" 2>/dev/null || true
    fi
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: must run as root" >&2
    exit 1
fi

if [ ! -f "${PROFILE_DIR}/packages.x86_64" ]; then
    echo "ERROR: ${PROFILE_DIR}/packages.x86_64 not found" >&2
    exit 1
fi

echo ":: Profile:  ${PROFILE_DIR}"
echo ":: Output:   ${OUTPUT_DIR}"
echo ":: Work dir: ${WORK_DIR}"

mkdir -p "$WORK_DIR/mnt" "$OUTPUT_DIR"

# --- Create raw image and mount ---
echo ":: Creating ${ROOT_SIZE} raw image..."
truncate -s "$ROOT_SIZE" "${WORK_DIR}/${IMAGE_NAME}"
mkfs.ext4 -F -L harbor_root "${WORK_DIR}/${IMAGE_NAME}"

LOOP_DEV=$(losetup --find --show "${WORK_DIR}/${IMAGE_NAME}")
echo ":: Loop device: ${LOOP_DEV}"
mount "$LOOP_DEV" "${WORK_DIR}/mnt"

# --- Read package list ---
mapfile -t PACKAGES < <(sed -e '/^#/d' -e '/^$/d' "${PROFILE_DIR}/packages.x86_64")
echo ":: Installing ${#PACKAGES[@]} packages via pacstrap..."

# --- Pacstrap (without running mkinitcpio via pacman hooks) ---
PACMAN_CONF="${PROFILE_DIR}/pacman.conf"

# Create a hook override to skip mkinitcpio during pacstrap.
# We run it manually after copying the overlay with our custom preset/config.
mkdir -p "${WORK_DIR}/mnt/etc/pacman.d/hooks"
cat > "${WORK_DIR}/mnt/etc/pacman.d/hooks/90-mkinitcpio-install.hook" << 'HOOK'
[Trigger]
Type = Path
Operation = Install
Operation = Upgrade
Target = usr/lib/modules/*/vmlinuz
Target = usr/lib/initcpio/*

[Action]
Description = Skipping mkinitcpio during build...
When = PostTransaction
Exec = /usr/bin/true
HOOK

if [ -f "$PACMAN_CONF" ]; then
    pacstrap -C "$PACMAN_CONF" -c -G -M "${WORK_DIR}/mnt" "${PACKAGES[@]}"
else
    pacstrap -c -G -M "${WORK_DIR}/mnt" "${PACKAGES[@]}"
fi

# Remove the hook override
rm -f "${WORK_DIR}/mnt/etc/pacman.d/hooks/90-mkinitcpio-install.hook"

# --- Copy airootfs overlay ---
if [ -d "${PROFILE_DIR}/airootfs" ]; then
    echo ":: Copying airootfs overlay..."
    cp -a "${PROFILE_DIR}/airootfs/." "${WORK_DIR}/mnt/"
fi

# --- Apply file permissions from profiledef.sh ---
echo ":: Applying file permissions..."
(
    # Source profiledef.sh to get file_permissions array
    declare -A file_permissions
    # shellcheck disable=SC1090,SC1091
    source "${PROFILE_DIR}/profiledef.sh"
    # shellcheck disable=SC2154
    for path in "${!file_permissions[@]}"; do
        IFS=':' read -r owner group mode <<< "${file_permissions[$path]}"
        if [ -e "${WORK_DIR}/mnt${path}" ]; then
            chown "${owner}:${group}" "${WORK_DIR}/mnt${path}"
            chmod "$mode" "${WORK_DIR}/mnt${path}"
        fi
    done
)

# --- System configuration ---
echo ":: Configuring system..."

# Hostname
echo "nest" > "${WORK_DIR}/mnt/etc/hostname"

# Locale
arch-chroot "${WORK_DIR}/mnt" locale-gen 2>/dev/null || true

# Enable services
arch-chroot "${WORK_DIR}/mnt" systemctl enable \
    systemd-networkd \
    systemd-resolved \
    sshd \
    docker \
    mnt-synology-harbor_srv.mount

# Generate initramfs (now with our custom preset and hooks config)
arch-chroot "${WORK_DIR}/mnt" mkinitcpio -P

# --- Finalize ---
echo ":: Syncing and unmounting..."
sync
umount "${WORK_DIR}/mnt"
losetup -d "$LOOP_DEV"
unset LOOP_DEV

# --- Compress and move to output ---
echo ":: Compressing image..."
zstd -T0 -10 "${WORK_DIR}/${IMAGE_NAME}" -o "${OUTPUT_DIR}/${IMAGE_NAME}.zst"

# Generate checksum
sha256sum "${OUTPUT_DIR}/${IMAGE_NAME}.zst" > "${OUTPUT_DIR}/${IMAGE_NAME}.zst.sha256"

IMAGE_SIZE=$(stat -c %s "${OUTPUT_DIR}/${IMAGE_NAME}.zst")
echo ":: Done! Image: ${OUTPUT_DIR}/${IMAGE_NAME}.zst ($(numfmt --to=iec "$IMAGE_SIZE"))"
