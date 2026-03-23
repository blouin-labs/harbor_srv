# CLAUDE.md

Working conventions for this repository. Keep this file up to date as the project evolves — Claude reads it at the start of every session, so stale information here leads to stale behavior.

## Branch model

- **`staging`** — default branch, integration target. All PRs go here.
- **`main`** — production. Promoted from `staging` only, never committed to directly.
- **Feature branches** — `feat/`, `fix/`, `docs/`, `chore/` prefixes. Always branch from `staging`.

Promotion to production is done via the **Promote** workflow in GitHub Actions (Actions → Promote → Run workflow). Never push directly to `main`.

Never create merge commits. Always rebase feature branches onto `staging` before opening a PR.

## CI/CD

- `ci.yml` — triggers on push/PR to `staging`. Runs shellcheck then builds the root image. Artifacts retained 30 days.
- `promote.yml` — `workflow_dispatch` only. Verifies CI is green on `staging`, then fast-forwards `main` to `staging`. Requires typing `"promote"` to confirm (server will reboot).
- `deploy.yml` — triggers on push to `main`. Downloads the last successful CI artifact from `staging` and flashes the server via the self-hosted runner (`harbor-srv`).

No deploy ever rebuilds the image — it always uses the artifact already produced by CI on `staging`.

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

- Push directly to `staging` or `main`. All work goes through a PR for the user to review. Promotion is via the Promote workflow, not direct push.
- Merge or approve PRs unless explicitly asked.
- Amend commits that have already been pushed.
- Use `--force` push on any branch.
- Grant the runner broad sudo or root access.
