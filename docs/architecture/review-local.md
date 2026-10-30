# Local review — bb-homelab (chore/169-persistent-journal)

- Date: 2026-10-30
- Commit: cbc1a95 + review fixes
- Scope: branch diff origin/main...HEAD (bootstrap journald drop-in, bootstrap.sh step, README, PROJECT_LOG)
- Checks run: design · docs · security · correctness (combined pass; no application code, no tests in scope)
- Verdict: ship · Must 0 · Should 3 (fixed) · Nice 1 (fixed)

## Pre-merge gate (head SHA pending)

| Step | Result |
|---|---|
| 1 Tests | shellcheck clean · markdownlint clean (repo has no test suite, see CLAUDE.md deviations) |
| 2 Coverage | n/a (no application code) |
| 3 SonarQube | CI check on the PR |
| 4 Secrets | gitleaks clean (origin/main..HEAD) · no tracked .env · diff read: nothing sensitive |
| 5 QA pass | pending: apply on the Pi, check `cat-config`, `/var/log/journal`; `--list-boots` > 1 after next approved reboot |

- Gate: **GREEN for push**; merge after step 5 on the Pi

## 🔴 Must Have

_None._

## 🟡 Should Have

- `bootstrap/bootstrap.sh:288` `[correctness]` · `$0` wrong if sourced · fixed: `${BASH_SOURCE[0]}`
- `bootstrap/bootstrap.sh:290` `[docs]` · curl-downloaded run skips the step · README states "from a clone only"; kept (single source of truth for the drop-in)
- `bootstrap/README.md:112` `[docs]` · `--disk-usage` comment inaccurate · fixed: `journalctl --flush` + `ls /var/log/journal`

## 🔵 Nice to Have

- `bootstrap/bootstrap.sh:301` `[correctness]` · flush the current boot to disk · fixed: `journalctl --flush`

## ⚪ Disagree / Intentional

_None._

## Per-dimension summary

- Design: minimal drop-in + idempotent step · Docs: procedure and runbook accurate · Tests: n/a · Security: 0644 root file, no secret · Correctness: precedence 50- over 40- confirmed
