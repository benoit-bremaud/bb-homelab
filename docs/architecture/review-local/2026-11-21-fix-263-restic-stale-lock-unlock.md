# Local review — bb-homelab (fix/263-restic-stale-lock-unlock)

Pre-push review of the stale-lock cleanup in the vaultwarden off-site script.

- Date: 2026-11-21
- Commit: f9ef645
- Scope: branch diff `origin/main...HEAD`
- Checks run: adversarial (fresh reviewer, 2 rounds) · tests · shellcheck and markdownlint (CI mirror) · SonarQube · secrets
- Verdict: ship · Must 0 · Should 0 · Nice 0 open

## Adversarial review (#236)

- Round 1 on `2792f1d`: Must 0 · Should 4 · Nice 3 · unverified 1 · Push gate: open
- Round 2 on `f9ef645`: 6 fixed · 1 partly fixed (scope: Home Assistant script and real-restic test deferred) · 0 regressed · new Must 0 · **Push gate: open**
- Optional second review (owner's own account): not run

## Pre-merge gate (pre-push run)

| Step | Result |
|---|---|
| 0 CI mirror | ✅ shellcheck 0.10.0 (action 2.0.0) clean · markdownlint-cli2 0.13.0: 0 errors · CodeQL, Scorecard, dependency-review CI-only |
| 1 Tests | ✅ `services/vaultwarden/tests/offsite-test.sh` 2/2; mutations (`--remove-all`, `--quiet`, no unlock) fail it |
| 2 Coverage | n/a (shell, no coverage runner) |
| 3 SonarQube | ✅ PASSED (project `bb-homelab`) |
| 4 Secrets | ✅ gitleaks clean on `origin/main..HEAD` · no tracked `.env` · diff read: nothing sensitive |
| 5 E2E/smoke | ⏸ planted stale lock with real restic 0.18.0 on the Pi after merge (local run refused by the sandbox) |

- Gate: **pre-push green**

## 🔴 Must Have

_None._

## 🟡 Should Have

_None._

## 🔵 Nice to Have

_None._

## ⚪ Disagree / Intentional

- `services/vaultwarden/scripts/offsite.sh` `[adversarial]` · no `--retry-lock` on `unlock` and a failed unlock stops the run without heartbeat: `unlock` takes no lock, and the Kuma alert is the designed signal

## Per-dimension summary

- Adversarial: safety property now tested, claims narrowed to restic 0.18.0 behaviour · Tests: stub at the boundary, order and failure path covered · Docs: BACKUP.md and script comment agree · Security: no secrets · Follow-ups: Home Assistant script (own repo), `flock` path independent of `XDG_RUNTIME_DIR`
