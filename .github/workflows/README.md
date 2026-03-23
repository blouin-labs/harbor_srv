[← harbor_srv](../../README.md)

# .github/workflows/

CI/CD pipeline for harbor_srv. Uses a two-branch model:

- **Feature branches** (`feat/`, `fix/`, `docs/`, `chore/`) — local development, PR'd into `staging`
- **`staging`** — integration branch; PRs and pushes trigger CI (shellcheck + image build)
- **`main`** — production; fast-forward promoted from `staging` when ready to deploy

README-only changes do not trigger a build.

## Branch workflow

```
feat/my-thing  →  PR to staging  →  CI runs  →  merge (rebase)
                                                      ↓
                             Actions → Promote → Run workflow   ← promote when ready
                                                      ↓
                                               deploy.yml fires
```

Feature branch rule: always `git rebase origin/staging` before opening a PR. Never merge.

Promote via **Actions → Promote → Run workflow**. Type `promote` to confirm. The workflow verifies CI is green on `staging` before touching `main`.

## Table of Contents

- [ci.yml](#ciyml)
  - [Triggers](#triggers)
  - [check job](#check-job)
  - [build job](#build-job)
  - [Artifact](#artifact)
- [promote.yml](#promoteyml)
- [deploy.yml](#deployyml)

---

## [ci.yml](ci.yml)

Two-job pipeline: `check` must pass before `build` runs.

### Triggers

Runs on:
- Push to the `staging` branch
- Pull requests targeting `staging`

Only fires when files under `profile/**` or `scripts/**` change.

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

---

## [promote.yml](promote.yml)

`workflow_dispatch` only — triggered manually via the GitHub Actions UI.

Requires typing `"promote"` in the confirmation input before any action is taken. Fails immediately if the input doesn't match.

Steps:
1. **Confirm** — validates the confirmation input.
2. **Verify CI** — checks the latest `build` job on `staging` is `success`. Aborts if not.
3. **Fast-forward main** — updates `main` to `staging`'s HEAD via the GitHub API (`force: false`). Will fail safely if the branches have somehow diverged.

Triggers `deploy.yml` as a side effect of the push to `main`.

---

## [deploy.yml](deploy.yml)

Triggers on push to `main` (and `workflow_dispatch`). Fetches the artifact from the last successful CI run on `staging` and flashes it to the server via the self-hosted runner.
