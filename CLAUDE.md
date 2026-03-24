# CLAUDE.md

Working conventions for this repository. Keep this file up to date as the project evolves — Claude reads it at the start of every session, so stale information here leads to stale behavior.

## Branch model

- **`staging`** — default branch, integration target. All PRs go here.
- **`main`** — production. Promoted from `staging` only, never committed to directly.
- **Feature branches** — `feat/`, `fix/`, `docs/`, `chore/` prefixes. Always branch from `staging`.

Promotion to production is done via the **Promotion** workflow in GitHub Actions. Never push directly to `main`.

Never create merge commits. Always rebase feature branches onto `staging` before opening a PR.

At the start of every session, fetch and pull `staging` before branching:
```bash
git checkout staging && git pull
```
Never branch from a stale or in-progress branch — the local tree may be behind remote.

## CI/CD

- `check.yml` — triggers on PR to `staging`. Runs shellcheck only. Fast gate — no build.
- `build.yml` — triggers on push to `staging`. Builds the root image, uploads artifact named `harbor_srv-root-{sha}`. Artifacts retained 30 days.
- `select-runner.yml` — reusable `workflow_call`. Picks the best available runner: `wsl-docker-runner` → `harbor-srv-docker` → `ubuntu-latest`. `harbor-srv` (bare-metal) is excluded — reserved for deploy only.
- `promotion.yml` — `workflow_dispatch` only. Action dropdown with three options:
  - `promote-and-deploy` (default) — verifies CI on `staging`, fast-forwards `main`, then flashes the server. Requires `"ok reboot"` to confirm. Server will reboot.
  - `promote` — verifies CI on `staging` and fast-forwards `main`. No confirmation required.
  - `deploy` — flashes the server without promoting. Requires `"ok reboot"` to confirm. Optional `run_id` input; defaults to latest successful staging build.

No deploy ever rebuilds the image — it always uses the artifact already produced by CI on `staging`.

## Server access

```bash
ssh -i ~/.ssh/harbor_srv root@192.168.1.5
```

## Runner / sudo

The GitHub Actions runner (`harbor-srv`) must never have root or sudo access directly. Privileged operations (e.g. `harbor-deploy`) are invoked via `sudo` to specific whitelisted scripts only — never `sudo bash` or unrestricted sudo.

## Commits

Follow [Conventional Commits](https://www.conventionalcommits.org): `feat:`, `fix:`, `docs:`, `chore:`, etc.

## Issues

1. **Check for a related issue before starting any non-trivial work.** Read the full issue — description and all comments — for context, prior decisions, or constraints.
2. **All non-trivial work must be associated with an issue.** If one doesn't exist, create it first. Trivial one-liner fixes may skip this. Issues describe the *why* — motivation, constraints, desired outcome — not the implementation.
3. **Apply labels** when creating or working an issue — type (`bug`, `enhancement`, `documentation`, `security`, `golden image`) and priority (`priority: critical/high/medium/low`).
4. **Post the plan as an issue comment before executing.** The local plan file is Claude's scratchpad; the issue comment is the durable record.
5. **Before adding `Closes #N` to a PR**, re-read the issue description and all comments to confirm the PR fully addresses the *why*. If the issue spans multiple PRs, use `Refs #N` instead.
6. **Close issues with a summary** — re-read the full thread, confirm nothing was missed, close with a brief comment.

## Never do

- Push directly to `staging` or `main`. All work goes through a PR for the user to review. Promotion is via the Promotion workflow, not direct push.
- Merge or approve PRs unless explicitly asked.
- Amend commits that have already been pushed.
- Use `--force` push on any branch.
- Grant the runner broad sudo or root access.
