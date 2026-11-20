# Local review — bb-homelab (docs/131-log-caddy-hardening)

Review of the PROJECT_LOG entries for the PR #253 merge and its Pi deploy.

- Date: 2026-11-20
- Commit: `c8a9e40`
- Scope: branch diff `origin/main...HEAD` (`PROJECT_LOG.md` only)
- Checks run: adversarial (fresh reviewer, 3 rounds) · lint · secrets · SonarQube
- Verdict: ship as-is · Must 0 · Should 1 · Nice 0

## Adversarial review (#236)

- Round 1 on the deploy evidence: Must 4 · Should 3 · Nice 2 · Push gate: closed.
- Round 2 on `bfcbda9`: 8 fixed · 1 Nice left (optional) · new Must 1 (raw Pi output not supplied) · Push gate: closed.
- Round 3 on `c8a9e40`: Must fixed with the owner's raw Pi output · 2 Nice fixed · **Push gate: open**.
- Optional second review (owner's own account): not run.

## Pre-merge gate (head SHA `c8a9e40`)

| Step | Result |
|---|---|
| 1 Tests | n/a: docs-only diff; `markdownlint-cli2 PROJECT_LOG.md` 0 issues |
| 2 Coverage | n/a: no code (repo deviation, see `CLAUDE.md`) |
| 3 SonarQube | ✅ PASSED on `c8a9e40` |
| 4 Secrets | ✅ gitleaks clean (`origin/main..HEAD`, 4 commits) · no tracked .env · diff read: nothing sensitive |
| 5 E2E/smoke | n/a: no runtime change |

- Gate: **GREEN, not attested** (no `scripts/attest.sh`): merge on the owner's explicit yes.

## 🔴 Must Have

_None._

## 🟡 Should Have

- Pi · The time the leaf certificate was read is not recorded. Re-read it with `date -u` before the merge: `notAfter` must be in the future. The log text does not change.

## 🔵 Nice to Have

_None._

## ⚪ Disagree / Intentional

- `docs/architecture/review-local/2026-11-18-fix-131-harden-caddy.md:58` · The post-restore `stat` Nice is covered by the ownership check in the deploy entry.

## Per-dimension summary

- Adversarial: every log claim matches the raw Pi output.
- Out of scope: "or Caddy fails to start" (compose and README) is only true for the top-level folders; #131 follow-up.
