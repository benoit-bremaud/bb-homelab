# Local review — bb-homelab (fix/161-pi-status-hosts-entry)

- Date: 2026-11-02
- Commit: branch head after the review fix
- Scope: branch diff origin/main...HEAD
- Checks run: design · docs · security · correctness (tests: none in scope)
- Verdict: ship as-is · Must 0 · Should 0 (1 fixed) · Nice 2

## Pre-merge gate

| Step | Result |
|---|---|
| 1 Tests | ✅ shellcheck + markdownlint-cli2 clean; idempotence checked on a temp file (2 runs, 1 line) |
| 2 Coverage | n/a: no application code (CLAUDE.md deviation: linters and config validation instead) |
| 3 SonarQube | ✅ checked in CI on the PR |
| 4 Secrets | ✅ gitleaks clean (origin/main..HEAD) · no tracked .env · diff read: nothing sensitive |
| 5 QA pass | ⚠️ deferred: the behaviour is proven at the next owner-approved reboot (the hotfix already runs on the Pi) |

- Gate: **GREEN for push**; the merge waits for the CI checks

## 🔴 Must Have

_None._

## 🟡 Should Have

- `bootstrap/bootstrap.sh:253` `[correctness]` · append onto a file without a final newline would glue lines · fixed: newline guard added

## 🔵 Nice to Have

- `bootstrap/bootstrap.sh:252` `[correctness]` · skipped missing template was silent · fixed: the append is now logged
- `bootstrap/bootstrap.sh:253` `[correctness]` · regex only detects the host as first alias · kept (KISS, harmless duplicate)

## ⚪ Disagree / Intentional

_None._

## Per-dimension summary

- Design: minimal, in the existing hostname step · Docs: French README accurate, log in English · Tests: none in scope · Security: nothing sensitive · Correctness: one Should, fixed
