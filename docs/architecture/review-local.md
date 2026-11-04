# Local review — bb-homelab (fix/202-sd-card-disk-alert)

- Date: 2026-11-04
- Commit: 494be7d (round 3), round 1 on 91e6731, round 2 on cd23fbf
- Scope: branch diff `origin/main...HEAD` (disk usage check script, `storage/DISK-ALERT.md`,
  activity diagram, `storage/README.md` row, `docs/security/AUDIT.md` risk R3)
- Checks run: adversarial (3 rounds) · docs · security (diff read, gitleaks) · CI mirror
  (shellcheck, markdownlint); design and tests proportional (one script, no test suite in the
  repository), containers not applicable
- Verdict: ship as-is · Must 0 · Should 0 · Nice 0 open

## Adversarial review

- Round 1 on `91e6731`: Must 1 · Should 4 · Nice 6 · unverified 2 · Push gate: closed
- Round 2 on `cd23fbf` (91e6731 squashed, unpushed): 10 fixed · 0 not fixed · 0 regressed ·
  new Must 0 · new Nice 3 (one round 1 Nice partly fixed) · Push gate: open
- Round 3 on `494be7d`: 4 fixed · 0 not fixed · 0 regressed · new findings 0 ·
  **Push gate: open**
- Hosted automated reviews (filled at the pre-merge run): pending

## Pre-merge gate (head SHA 494be7d)

| Step | Result |
|---|---|
| 0 CI mirror | ✅ shellcheck 0.10.0 (`-e SC1091`, as CI) clean · ✅ markdownlint, 0 error on the changed files (MD060 known false positive on pre-existing tables) · yamllint: no YAML in the diff · CodeQL, Scorecard, dependency review: CI-only |
| 1 Tests | n/a: no test suite; script run by hand in 7 cases (under threshold, over threshold, missing mount, no `df` figure, URL with a query, `down` and `up` push through a local stub) |
| 2 Coverage | n/a: project deviation in `CLAUDE.md` (linters and docs instead) |
| 3 SonarQube | ⏸ deferred to the pre-merge run (`--push`) |
| 4 Secrets | ✅ gitleaks clean (`origin/main..HEAD`) · no tracked `.env` · diff read: no token, URL or address |
| 5 E2E/smoke | n/a: no runnable product in the diff |

- Gate: `--push`: **pre-push green**, SonarQube deferred (never GREEN)

## 🔴 Must Have

- `storage/scripts/disk-usage-check.sh:8`, `storage/DISK-ALERT.md`, diagram, commit body
  `[adversarial]` · coverage overstated: Kuma shares the Pi and `/mnt/appdata`, so a dead Pi or
  a missing HDD stops Kuma too (ADR 0004 layer 2) · "Ce qui n'est pas couvert" section, commit
  reworded — fixed in cd23fbf

## 🟡 Should Have

- Empty `df` figure counted as ok; `~/.cache` may be missing; 1800 s interval too tight (now
  2700 s); install while `/` is over 80 % hides other causes; "au-delà" vs `-ge`; threshold
  unexplained (risk R3); no "when the alert fires" section `[adversarial|docs]` · all fixed in
  cd23fbf

## 🔵 Nice to Have

- `down` push naming the mount point, inode check, failure-only log, first-UP test, risk R3
  detection, duplicated note `[adversarial|docs]` · fixed in cd23fbf
- Diagram final nodes and failed-push branch, `msg` sanitising, missing URL logged, hot-unplugged
  HDD gap documented `[adversarial]` · fixed in 494be7d

## ⚪ Disagree / Intentional

- `disk-usage-check.sh`: exit on a failed push, unlike `appdata-backup.sh` · here the push is
  the whole output
- Hard-coded `/home/benoit/...` cron paths · same convention as `APPDATA-BACKUP.md`

## Per-dimension summary

- Adversarial: one Must in round 1, all findings fixed by round 3 · Docs: wording and an
  alert-handling section, fixed · Security: no leak, URL on stdin and validated · Design, tests:
  proportional, nothing to add
- Out of scope, pre-existing, filed: recovery message vs ADR 0004 (#209), `storage/README.md`
  stale and in English (#210), local shellcheck command narrower than CI (#211)
