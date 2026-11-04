# Local review — bb-homelab (docs/202-docker-storage-move)

- Date: 2026-11-04
- Commit: 6a1f50c (round 4); rounds 1 to 3 on ced7b96, 6a7c4e9, 622cf90
- Scope: branch diff `origin/main...HEAD` (runbook `storage/DOCKER-STORAGE-MOVE.md`,
  ADR 0008, `docs/decisions/README.md`, `storage/LAYOUT.md`, `storage/README.md`)
- Checks run: adversarial (4 rounds) · docs · security (diff read, gitleaks) · CI mirror
  (markdownlint); design, tests and containers not applicable (documentation only; facts on
  the Pi gathered read-only)
- Verdict: ship as-is · Must 0 · Should 0 · Nice 0 open

## Adversarial review

- Round 1 on `ced7b96`: Must 1 · Should 9 · Nice 6 · unverified 2 · Push gate: closed
- Round 2 on `6a7c4e9`: all round 1 items fixed but one (backup check) · new Should 2 · new
  Nice 6 · Push gate: open
- Round 3 on `622cf90`: 7 fixed · 1 regressed (ADR matrix totals) · Push gate: open
- Round 4 on `6a1f50c`: 1 fixed · new findings 0 · **Push gate: open**
- Hosted automated reviews (filled at the pre-merge run): pending

## Pre-merge gate (head SHA 6a1f50c)

| Step | Result |
|---|---|
| 0 CI mirror | ✅ markdownlint, 0 error on the changed files (MD060 known false positive) · shellcheck, yamllint, hadolint: no file in scope · CodeQL, Scorecard, dependency review: CI-only |
| 1 Tests | n/a: documentation only; the runbook runs later on the Pi with the owner |
| 2 Coverage | n/a: project deviation in `CLAUDE.md` |
| 3 SonarQube | ⏸ deferred to the pre-merge run (`--push`) |
| 4 Secrets | ✅ gitleaks clean (`origin/main..HEAD`) · no tracked `.env` · diff read: no secret, tunnel name or AI tool name |
| 5 E2E/smoke | n/a: no runnable product in the diff |

- Gate: `--push`: **pre-push green**, SonarQube deferred (never GREEN)

## 🔴 Must Have

- `storage/DOCKER-STORAGE-MOVE.md` `[adversarial]` · a Docker restart changes the quick-tunnel
  URL, so the "Kuma all green" check would trigger a needless rollback · conditional tunnel
  step, tunnel monitor excluded from the rollback criterion — fixed in 6a7c4e9
- `storage/DOCKER-STORAGE-MOVE.md` `[docs]` · broken link to `DISK-ALERT.md` (only in #212),
  unchecked copy, fragile rollback, free-hand containerd edit · fixed in 6a7c4e9

## 🟡 Should Have

- Copy check before the move, leftover shims and mounts (`-x`), config written before `mv`,
  `mv -T`, same-day vs later rollback, backup and #168 preconditions, backup window, disk by
  mount, 1.5x space, orphan volume moved to the cleanup, indexes and ADR 0008
  `[adversarial|docs]` · fixed in 6a7c4e9
- UAS journal filter, archives instead of logs `[adversarial]` · fixed in 622cf90
- ADR 0008 matrix totals and sensitivity `[adversarial]` · fixed in 6a1f50c

## 🔵 Nice to Have

- Two-pass copy, `du -x`, names-only diff, `daemon.json` command and validation, run-state
  note, guard before `rm -rf`, docs link, run date in `PROJECT_LOG.md`, boot diagnostics
  (6a7c4e9); idempotent containerd line, smartctl on the disk, full tunnel rotation, SD space
  before a later rollback (622cf90) `[adversarial|docs]` · all fixed

## ⚪ Disagree / Intentional

_None._

## Per-dimension summary

- Adversarial: one Must in round 1, all findings fixed by round 4 · Docs: link, rollback and
  check gaps fixed · Security: no leak · Design, tests: not applicable
- Out of scope, filed: the Docker and containerd settings and drop-ins are not tracked in
  `bootstrap/` (#213); `docs/security/AUDIT.md` risk R3 to update when #202 closes
