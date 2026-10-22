# Local review — bb-homelab (branch `feat/133-backup-alert-offpi`)

- Date: 2026-10-23
- Commit: 0301986 (round 1) → fixes applied in the follow-up commit
- Scope: branch diff `origin/main...HEAD` — backup heartbeat (n8n,
  Vaultwarden), off-Pi rsync pull (script + user systemd units), backup
  docs, UML sequence + state diagrams, QA evidence
- Checks run: design · docs · tests · security · correctness · `--push`
  mode (no QA pass; the live QA happened on the Pi, see
  `docs/architecture/qa/2026-10-23-backup-alert/`)
- Verdict (round 1): fix Must Have first · Must 1 · Should 8 · Nice 6 ·
  Disagree 3 — **all Must and Should resolved before push**

## Pre-merge gate (head SHA 419fa0e, after Codex rounds 1–2)

| Step | Result |
|---|---|
| 1 Tests | ✅ `shellcheck` on the 3 scripts · ✅ `markdownlint-cli2 '**/*.md'` 0 issues beyond MD060 · ✅ `systemd-analyze --user verify` on both units · YAML: CI `Lint YAML` green (local yamllint install broken) · no application test suite (infra repo, see CLAUDE.md deviation) |
| 2 Coverage | n/a (no application code) · docs: every new artefact has its doc (`OFFPI-COPY.md`, both `BACKUP.md` sections, `storage/README.md` row) |
| 3 SonarQube | ✅ `QUALITY GATE STATUS: PASSED` (local instance, project `bb-homelab`) |
| 4 Secrets | ✅ gitleaks clean (`--log-opts=--all`, public repo) · no tracked `.env` · diff read: push URLs live only in `~/.config/bb-homelab/` on the Pi, usage line uses a `<tailscale-ip>` placeholder |
| 5 QA pass | ✅ full: Pi clone switched to the branch, both cron lines run as cron would → `n8n-2026-10-23_005600.tar.gz` (404K) and `vaultwarden-2026-10-23_005600.tar.gz` (32K), `heartbeat sent to Uptime Kuma` in both logs, Kuma heartbeats `UP / OK` at 22:56 UTC · `pull-backups.sh` from the PC rc 0, both archives landed in `600` · screenshots: `qa/2026-10-23-backup-alert/01-kuma-push-monitors-up.jpg`, `02-kuma-after-real-cron-run.jpg` |

- Gate: **GREEN — merge authorised**. Bot reviews: Codex only (2 findings,
  both fixed: `95e0f39`, `419fa0e`); CodeRabbit uninstalled by the owner
  (paid), Copilot auto-review silent since PR #132 — owner decision
  2026-10-23: proceed without them.

## 🔴 Must Have

- `services/vaultwarden/scripts/backup.sh:41` `[docs|correctness]` ·
  the `(use once HDD C lands — issue #19)` comment ended up under the
  new `KUMA_PUSH_URL` block instead of the `BACKUP_DIR` example ·
  **fixed**: comment moved back under `KEEP=14`.

## 🟡 Should Have

- `services/*/scripts/backup.sh` heartbeat `[security]` · push URL on the
  `curl` command line is visible in `ps` · **fixed**: URL handed to curl
  through `-K -` on stdin, `--retry 2` added.
- `services/*/scripts/backup.sh` heartbeat `[correctness]` · the script
  rewrote the stored URL (`%%\?*` + hard-coded query) · **fixed**: URL
  called as stored (works for Kuma and Healthchecks.io alike).
- `storage/scripts/pull-backups.sh` `[security]` · archives could be
  overwritten by the Pi, SSH agent forwarding not explicitly off,
  symlinks followed · **fixed**: `--ignore-existing` for `*.tar.gz`,
  `-o ForwardAgent=no -o ClearAllForwardings=yes`, `--no-links`,
  rsync ≥ 3.2.5 requirement documented (PC runs 3.4.1).
- `storage/scripts/pull-backups.sh` `[correctness]` · first failing
  source aborted the loop · **fixed**: loop continues, exit code 1 at
  the end.
- `storage/systemd/bb-homelab-backup-pull.service` `[design]` ·
  `network-online.target` is meaningless for a user unit; no retry, no
  signal on failure · **fixed**: removed, `Restart=on-failure` +
  `RestartSec=5min`, `OnFailure=` → new
  `bb-homelab-backup-pull-failed.service` (desktop notification).
- `services/*/BACKUP.md` `[docs]` · two contradicting cron recipes
  (`/var/backups/…` vs `~/backups/…`), MD012 double blank line, retries
  not stated · **fixed**: one real cron line, `BACKUP_DIR` ↔ `SOURCES`
  cross-reference, retries `0`.
- `docs/architecture/diagrams/backup/01-sequence.md` `[docs]` · "lecture
  seule" was wrong (the key is a normal shell key), Healthchecks.io
  claim contradicted ADR 0004, DOWN note sat outside the failure branch
  · **fixed**.
- `storage/OFFPI-COPY.md` `[docs]` · jitter window, which files are
  copied, no PC-side retention, failure notification · **fixed**.

## 🔵 Nice to Have (filed as a follow-up issue)

- `services/n8n/scripts/backup.sh` `[correctness]` · pre-existing:
  `KEEP=0` not guarded like the Vaultwarden script.
- `storage/systemd/*.service` `[security]` · hardening directives
  (`ProtectSystem`, `PrivateTmp`…) for the user units.
- `storage/OFFPI-COPY.md` `[docs]` · `loginctl enable-linger` note and a
  reminder that the PC disk is the copy's only protection (encrypt).
- `services/*/BACKUP.md` `[docs]` · Kuma notification settings worth
  recording (resend interval, "important" flag).
- `services/*/scripts/backup.sh` `[design]` · heartbeat block duplicated
  twice; extract to a shared helper on the third copy.
- `storage/scripts/pull-backups.sh` `[correctness]` · `--retry` on the
  rsync side is not available; a second timer pass could cover a Pi
  that boots late.

## ⚪ Disagree / Intentional

- heartbeat block duplicated in two scripts `[design]` · rule of three;
  a helper now would be a speculative abstraction (KISS/YAGNI).
- PC → Pi pull direction `[security]` · intentional: the Pi holds no
  credential for the PC, so a compromised Pi cannot reach the copy
  (documented in `OFFPI-COPY.md` and the sequence diagram).
- no ADR `[docs]` · the feature applies ADR 0004 (monitoring) and the
  backup conventions already in place; the UML diagrams carry the
  decisions.

## Per-dimension summary

- Design: units and script stay flat and single-purpose; `pull()` helper
  removes the only real duplication · Docs: FR docs complete, one cron
  recipe per service · Tests: scripts exercised for real (Pi cron run,
  PC pull) · Security: token off the command line, pull hardened, no
  secret in git · Correctness: loop continues on failure, exit code
  propagated to systemd.
