# Local review — bb-homelab (docs/263-log-offsite-unlock-tunnel)

Pre-push review of the log entries for the Home Assistant off-site unlock and the n8n tunnel restart.

- Date: 2026-11-21
- Commit: ffffb99, plus the round 2 fix commit
- Scope: branch diff `origin/main...HEAD` (docs and `.gitignore` only)
- Checks run: adversarial (fresh reviewer, 2 rounds) · secrets · markdownlint (CI mirror) · SonarQube
- Verdict: ship · Must 0 · Should 0 · Nice 0 open

## Adversarial review (#236)

- Round 1 on `7bc19ee`: Must 1 · Should 3 · Nice 1 · unverified 2 · Push gate: closed
- Round 2 on `ffffb99`: 6 fixed · 0 not fixed · 0 regressed · new Must 0 · **Push gate: open**
- Round 2 Should (pentest-plan E2 wording) and Nice (`DOCKER-STORAGE-MOVE.md`, `.gitignore` `.env.bak*`) applied in the following commit
- Optional second review (owner's own account): not run

## Pre-merge gate (pre-push run)

| Step | Result |
|---|---|
| 0 CI mirror | ✅ markdownlint-cli2 0.13.0 (action v16): 0 errors on the touched files outside the known MD060 false positive; other PR jobs (shellcheck, yamllint, hadolint) have no file in scope; CodeQL, Scorecard, dependency-review CI-only |
| 1 Tests | n/a (docs only) |
| 2 Coverage | n/a (docs only) |
| 3 SonarQube | ✅ PASSED (project `bb-homelab`) |
| 4 Secrets | ✅ gitleaks clean on `origin/main..HEAD` · no tracked `.env` · diff read: no hostname, no secret |
| 5 E2E/smoke | n/a (docs only) |

- Gate: **pre-push green**

## 🔴 Must Have

_None._

## 🟡 Should Have

_None._

## 🔵 Nice to Have

_None._

## ⚪ Disagree / Intentional

- `PROJECT_LOG.md` `[adversarial]` · "claude.ai n8n connector" names a service n8n talks to, not an authorship mark · `core.md` § Work discipline
- `services/caddy/README.md` `[adversarial]` · "may recreate cloudflared" is hedged on purpose: Compose recreates only on a config or image change

## Per-dimension summary

- Adversarial: stale "tunnel stopped" statements and the MCDA override fixed · Design, Tests: n/a (docs only) · Docs: consistent across README, plan, log · Security: exposure recorded as accepted risk, `.env` backup moved out of the Pi checkout and ignored · Correctness: backup gap is 2026-11-08 to 2026-11-14
