[← harbor_srv](../../README.md)

# .github/workflows/

CI pipeline for harbor_srv. Uses a three-branch model:

- **Dev branches** — local development, PR'd into `test`
- **`test`** — integration branch; PRs and pushes trigger CI (shellcheck + image build)
- **`main`** — stable, known-good; manual merge from `test` after verifying on the server. No CI triggers.

README-only changes do not trigger a build.

## Table of Contents

- [build.yml](#buildyml)
  - [Triggers](#triggers)
  - [check job](#check-job)
  - [build job](#build-job)
  - [Artifact](#artifact)

---

## [build.yml](build.yml)

Two-job pipeline: `check` must pass before `build` runs.

### Triggers

Runs on:
- Push to the `test` branch
- Pull requests targeting `test`

Only fires when files under `profile/**`, `scripts/**`, or `.github/workflows/**` change. Changes to `README.md` files are explicitly excluded.

### check job

Runs [shellcheck](https://www.shellcheck.net/) against all scripts and the profile definition:

- `profile/profiledef.sh`
- `scripts/build-image.sh`
- `scripts/install.sh`
- `scripts/deploy.sh`

Runs inside an `archlinux/archlinux:latest` container so the shell environment matches the build environment.

### build job

Runs `./scripts/build-image.sh profile/ output/` inside a **privileged** `archlinux/archlinux:latest` container. Privileged mode is required because `build-image.sh` uses loop devices (`losetup`) and `arch-chroot`, which need elevated kernel access unavailable in standard unprivileged containers.

Depends on `check` — if shellcheck fails, the image is not built.

### Artifact

Uploads `output/` as artifact `harbor_srv-root` with 30-day retention. Contents:

| File | Description |
|------|-------------|
| `harbor_srv-root.img.zst` | Compressed root filesystem image |
| `harbor_srv-root.img.zst.sha256` | SHA256 checksum |

Download with:

```bash
gh run download <run-id> -n harbor_srv-root -D /tmp/deploy
```
