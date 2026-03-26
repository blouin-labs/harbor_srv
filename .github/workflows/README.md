[← harbor_srv](../../README.md)

<!-- vale Microsoft.Headings = NO -->
# .github/workflows/
<!-- vale Microsoft.Headings = YES -->

CI/CD pipeline for harbor_srv. Uses a two-branch model:

- **Feature branches** (`feat/`, `fix/`, `docs/`, `chore/`)—local development, merged into `staging` via pull request
- **`staging`**: integration branch; PRs trigger checks, pushes trigger the image build
- **`main`**: production; fast-forward promoted from `staging` via the Promotion workflow

## Workflows

### [check.yml](check.yml)

Runs on **PR to `staging`**. Path-filtered—only fires when `profile/**`, `scripts/**`, `.github/workflows/**`, `**.md`, or `.vale.ini` change.

Three jobs run in parallel (each skipped if its paths didn't change):

| Job | Paths | What it does |
|-----|-------|--------------|
| `shellcheck` | `profile/**`, `scripts/**` | Runs [shellcheck](https://www.shellcheck.net/) on all shell scripts inside an `archlinux/archlinux` container |
| `actionlint` | `.github/workflows/**` | Runs [actionlint](https://github.com/rhysd/actionlint) to lint workflow files |
| `vale` | `**.md`, `.vale.ini` | Runs [Vale](https://vale.sh/) prose linter on all Markdown files |

An `all-checks` aggregator job collects results—this is the required status check on PRs.

---

### [build.yml](build.yml)

Runs on **push to `staging`** when `profile/**` or `scripts/**` change.

Builds the root filesystem image inside a privileged `archlinux/archlinux` container (privileged mode required for loop devices and `arch-chroot`). Uploads the result as artifact `harbor_srv-root-{sha}` with 30-day retention.

Uses [select-runner.yml](#select-runneryml) to pick the best available runner.

**Output artifact contents:**

| File | Description |
|------|-------------|
| `harbor_srv-root.img.zst` | Compressed root filesystem image |
| `harbor_srv-root.img.zst.sha256` | SHA256 checksum |

---

### [select-runner.yml](select-runner.yml)

Reusable workflow (`workflow_call`). Checks runner availability via the GitHub API and outputs a JSON runner label for the calling job.

Priority order: `wsl-docker-runner` → `harbor-srv-docker` → `ubuntu-latest`

The pipeline excludes the bare-metal `harbor-srv` runner—reserved for deploy only.

---

### [promotion.yml](promotion.yml)

`workflow_dispatch` only—triggered manually via **Actions → Promotion → Run workflow**.

Select an action from the dropdown:

| Action | What it does | Confirmation required |
|--------|-------------|----------------------|
| `promote-and-deploy` (default) | Verifies CI on `staging`, fast-forwards `main`, then flashes the server | `ok reboot` |
| `promote` | Verifies CI on `staging` and fast-forwards `main`. No deploy. | None |
| `deploy` | Flashes the server without promoting. Defaults to latest successful staging build; accepts optional `run_id`. | `ok reboot` |

All actions verify that `build.yml` is green on `staging` before touching `main`. No action ever rebuilds the image—it always uses the artifact already produced by `build.yml`.

---

### [compose-manage.yml](compose-manage.yml)

`workflow_dispatch` only. Runs container management commands on `harbor-srv` via `sudo harbor-compose-ctl`.

| Action | What it does |
|--------|-------------|
| `rescan` | Scans the NFS share for new or removed stacks |
| `update` | Pulls latest images and recreates changed containers |
| `stop` | Stops all managed stacks |
| `start` | Starts all managed stacks |
