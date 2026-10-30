# Local review — bb-homelab (branch diff main...docs/172-safe-uas-rollback)

- Date: 2026-10-30
- Commit: b6f0874 (the amended head only adds the Should Have fix and
  this report)
- Scope: branch diff `main...HEAD` (`storage/INVENTORY.md`,
  `PROJECT_LOG.md`, this report); docs-only, nothing changed on the Pi
- Checks run: docs · security · correctness (design, tests, containers:
  N/A, docs-only diff)
- Verdict: ship · Must 0 · Should 1 (fixed) · Nice 1 (kept)

## Pre-merge gate (head SHA b6f0874)

| Step | Result |
|---|---|
| 1 Tests | N/A (no application code); markdownlint-cli2 green except the known MD060 false positive at `storage/INVENTORY.md:41` (pre-existing) |
| 2 Coverage | N/A (no code); every touched file is documentation |
| 3 SonarQube | ⚠️ not run locally; the SonarCloud check runs on the PR |
| 4 Secrets | ✅ gitleaks clean (`origin/main..HEAD`) · no tracked `.env` · diff read: no address, no identifier |
| 5 QA pass | N/A (docs diff); the `sed` and `cat` commands were checked by hand against the quirk as appended (leading space) |

- Gate: **GREEN for push**; merge waits for the PR checks

## 🔴 Must Have

_None._

## 🟡 Should Have

- `storage/INVENTORY.md:120` `[correctness]` · `dmesg | grep` can
  return nothing (`dmesg_restrict`, ring buffer rolled over) and
  suggest the quirk is inactive · fixed: `sudo journalctl -k -b | grep
  -i 'UAS is ignored'` (owner MCDA 470/500 vs `sudo dmesg` 410)

## 🔵 Nice to Have

- `storage/INVENTORY.md:121-124` `[docs]` · "le disque reste le goulot"
  then "À revoir si … devient un goulot" is a mild repetition · kept

## ⚪ Disagree / Intentional

_None._

## Per-dimension summary

- Design: N/A · Docs: French Category A respected, review items 1-3
  and both Nice applied · Tests: N/A · Security: reboot only with
  physical access, no secret · Correctness: one re-check command fixed
