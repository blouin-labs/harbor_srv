# harbor_srv

[![CI](https://github.com/JCBlouin/harbor_srv/actions/workflows/ci.yml/badge.svg?branch=test)](https://github.com/JCBlouin/harbor_srv/actions/workflows/ci.yml)

A bare-minimum, stateless Arch Linux server for hosting Docker containers on a Lenovo ThinkPad connected to a Synology NAS.

The core idea: the OS is a disposable, reproducible artifact. When something goes wrong, you reflash — you don't troubleshoot. Upgrades are handled the same way as deployments.

## Table of Contents

- [Architecture](#architecture)
  - [Zero-drift guarantee](#zero-drift-guarantee)
  - [A/B boot with automatic fallback](#ab-boot-with-automatic-fallback)
- [Hardware](#hardware)
- [Repository layout](#repository-layout)
- [Getting started](#getting-started)
  - [First-time setup](#first-time-setup)
  - [Deploying an update](#deploying-an-update)
  - [SSH access](#ssh-access)
- [Making changes](#making-changes)
  - [Branch workflow](#branch-workflow)
- [Updating the stack](#updating-the-stack)

## Architecture

CI builds a root filesystem image from a package list and a config overlay. That image is written directly to one of two NVMe partitions (A/B layout). The bootloader automatically falls back to the previous partition if the new one fails to boot.

```
GitHub Actions
  └── pacstrap + profile/airootfs overlay
      └── harbor_srv-root.img.zst  (artifact)
            │
            ▼
      scripts/install.sh           (one-time, partitions NVMe)
      scripts/deploy.sh            (every release, writes to inactive slot)
            │
            ▼
      NVMe (476GB)
        nvme0n1p1   512MB   ESP (FAT32, systemd-boot)
        nvme0n1p2   10GB    Root A  (ext4)
        nvme0n1p3   10GB    Root B  (ext4)
        nvme0n1p4   ~456GB  Data    (ext4, /data)
            │
            ▼
      Synology NAS (192.168.1.10)
        /volume1/harbor_srv  →  /mnt/synology/harbor_srv
          docker/            →  Docker Compose stacks
```

### Zero-drift guarantee

Nothing on the root filesystem persists across deploys. The entire root is replaced on each deployment. Persistent state lives on the NFS share (Docker volumes, compose files) or the `/data` partition.

### A/B boot with automatic fallback

Each deploy writes a new image to the inactive root partition with a systemd-boot try-counter (`+3`). If the system fails to boot 3 times, systemd-boot automatically falls back to the other partition. On successful boot, `systemd-bless-boot.service` marks the entry as good.

## Hardware

| Component | Detail |
|-----------|--------|
| Machine | Lenovo ThinkPad (hostname: `harbor-srv`) |
| IP | 192.168.1.5 (static) |
| NVMe | 476GB |
| NAS | Synology at 192.168.1.10 |

## Repository layout

```
profile/                  OS profile — everything baked into the root image
  airootfs/               Config overlay, copied verbatim into the root
  packages.x86_64         Package list installed via pacstrap
  pacman.conf             pacman config used during build
  profiledef.sh           File permission overrides applied after overlay copy

scripts/
  build-image.sh          CI: builds the root filesystem image via pacstrap
  install.sh              One-time: partitions NVMe and writes first image
  deploy.sh               Each release: writes image to inactive slot, reboots

.github/workflows/
  ci.yml                  Runs on push/PR to test: shellcheck + build image + upload artifact
  deploy.yml              Runs on push to main (or manually): deploys last successful test artifact
```

## Getting started

### First-time setup

1. Boot a live Arch ISO from USB on the ThinkPad
2. Download the latest `harbor_srv-root` artifact from GitHub Actions
3. Run the installer:

```bash
curl -O https://raw.githubusercontent.com/JCBlouin/harbor_srv/main/scripts/install.sh
bash install.sh /dev/nvme0n1 harbor_srv-root.img.zst
```

4. Reboot — disable Secure Boot in UEFI first (bootloader is unsigned)

### Deploying an update

Deployments are automatic — merging `test` into `main` triggers `deploy.yml`, which downloads the last successful CI artifact from `test` and runs `harbor-deploy` on the server. No manual steps required.

To trigger a deploy manually (e.g. after a workflow-only change that didn't fire the path filter):

1. Go to **Actions → Deploy → Run workflow** in the GitHub UI.

### SSH access

```bash
ssh -i ~/.ssh/harbor_srv root@192.168.1.5
```

## Making changes

All OS configuration lives in `profile/`. To add a package, add it to `profile/packages.x86_64`. To add or change a config file, add it under `profile/airootfs/` at the path it should appear on the root filesystem.

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org) (`feat:`, `fix:`, `docs:`, `chore:`, etc.).

See [`profile/README.md`](profile/README.md) and [`scripts/README.md`](scripts/README.md) for details.

### Branch workflow

```
main        stable, production — only receives merges from test
 └── test   staging — only receives merges from feature branches
      └── your-branch   all work starts here
```

1. **Branch from `test`** — always, not from `main`:
   ```bash
   git checkout test && git pull
   git checkout -b feat/your-change
   ```
2. **Open a PR targeting `test`** — CI runs `check` + `build`, producing an artifact.
3. **Rebase and merge** into `test`.
4. **Test manually** on the server (trigger a deploy via Actions if needed).
5. **Open a PR from `test` to `main`** — no rebuild, just deploy.
6. **Merge** — `deploy.yml` downloads the already-built artifact from step 2 and deploys it.

> **Why branch from `test` and not `main`?** `test` is ahead of `main` by definition — it contains changes that have been built but not yet promoted. Branching from `main` causes duplicate commits with different SHAs once the branch is rebased onto `test`, leading to merge conflicts on the `test → main` PR.

## Updating the stack

All package versions and the build environment are pinned to a snapshot date. To upgrade to a newer point in time, edit **`.github/workflows/ci.yml`** only — two adjacent values:

1. Update `ARCH_SNAPSHOT` to the new date (`YYYY/MM/DD`). Check [archive.archlinux.org/repos](https://archive.archlinux.org/repos/) to confirm the date is available.
2. Update the `container.image` digest to match. Fetch it with:

```bash
docker manifest inspect --verbose archlinux/archlinux:latest \
  | grep -m1 '"digest"' | awk -F'"' '{print $4}'
```

3. Open a PR — CI builds the new image for review before it reaches the server.
