# Local review — bb-homelab (ci/175-bump-scorecard-action)

Pre-push review of the one-line scorecard-action bump that fixes the red OSSF Scorecard workflow.

- Date: 2026-11-02
- Commit: 41058bf
- Scope: branch diff origin/main...HEAD (`.github/workflows/scorecard.yml`)
- Checks run: security · correctness (design, docs and tests agents skipped: one pinned SHA, no code, no tests in scope)
- Verdict: ship as-is · Must 0 · Should 0 · Nice 1

## Pre-merge gate (head SHA 41058bf, `--push` mode)

| Step | Result |
|---|---|
| 1 Tests | n/a (no application code, no `justfile`) · yamllint clean |
| 2 Coverage | n/a (project deviation recorded in `CLAUDE.md`) |
| 3 SonarQube | ⚠️ gate OK on the last main analysis (`new_violations` 0); branch not scanned, workflow YAML not analysed |
| 4 Secrets | ✅ gitleaks clean (origin/main..HEAD) · no tracked .env · diff read: nothing sensitive |
| 5 QA pass | skipped (`--push`); proof = Scorecard run green on the branch |

- Gate: **push authorised**; merge waits for the green Scorecard run.

## 🔴 Must Have

_None._

## 🟡 Should Have

_None._

## 🔵 Nice to Have

- `.github/workflows/scorecard.yml:27` `[security]` · `actions/checkout`, `upload-artifact` (v4) and `codeql-action/upload-sarif` (v3) lag their latest majors · leave to Dependabot / a separate issue, out of scope here.

## ⚪ Disagree / Intentional

_None._

## Per-dimension summary

- Security: pin verified (annotated tag `v2.5.0` → commit `fa7117db…`); v2.5.0 pulls its image from `ghcr.io` instead of `gcr.io`, which removes the failing pull.
- Correctness: inputs used (`results_file`, `results_format: sarif`, `publish_results`) unchanged in the v2.5.0 release notes.
