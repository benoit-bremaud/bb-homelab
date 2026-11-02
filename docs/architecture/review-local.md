# Local review — bb-homelab (ci/175-bump-scorecard-action)

Pre-push review of the one-line scorecard-action bump that fixes the red OSSF Scorecard workflow.

- Date: 2026-11-02
- Commit: 41058bf + review fixes (head b6111a7)
- Scope: branch diff origin/main...HEAD (`.github/workflows/scorecard.yml`)
- Checks run: security · correctness · adversarial (design, docs and tests agents skipped: one pinned SHA, no code, no tests in scope)
- Verdict: ship · Must 1 (fixed: timeline and root cause corrected) · Should 2 (fixed) · Nice 1

## Pre-merge gate (head SHA b6111a7, `--push` mode)

| Step | Result |
|---|---|
| 1 Tests | n/a (no application code, no `justfile`) · yamllint clean |
| 2 Coverage | n/a (project deviation recorded in `CLAUDE.md`) |
| 3 SonarQube | ⚠️ gate OK on the last main analysis (`new_violations` 0); branch not scanned, workflow YAML not analysed |
| 4 Secrets | ✅ gitleaks clean (origin/main..HEAD) · no tracked .env · diff read: nothing sensitive |
| 5 QA pass | skipped (`--push`); partial proof: the image pull succeeds on branch runs 41430377142 (`f80f936`) and 41432672651 (`546ea26`, temporary `publish_results: false`, reverted); the action refuses non-default branches either way, so analysis and publication are pending on `main` after merge |

- Gate: **push authorised**; merge on the other required checks; Scorecard confirmed on `main` after merge.
- History: Scorecard has never passed on main (35 failures, 2026-06-16 to 2026-10-30). The image pull failures start on 2026-10-22; the earlier analysis-step failures have expired logs, so the analysis may still fail after this fix. #175 stays open until a green run on main.

## 🔴 Must Have

- `PROJECT_LOG.md` · `docs/architecture/review-local.md` `[correctness]` · the failure history was wrong (Scorecard has never passed on main; image pull failures only from 2026-10-22) · fixed in b6111a7; #175 stays open until a green run on main.

## 🟡 Should Have

- `docs/architecture/review-local.md:21` `[correctness]` · the QA row required a green branch run that the action cannot produce · fixed in 94dcd74: partial proof, analysis pending on `main`.
- `docs/architecture/review-local.md:21` `[correctness]` · branch run tied to the wrong commit · fixed in b6111a7: runs cited with their own SHAs.

## 🔵 Nice to Have

- `.github/workflows/scorecard.yml:27` `[security]` · `actions/checkout`, `upload-artifact` (v4) and `codeql-action/upload-sarif` (v3) lag their latest majors · leave to Dependabot / a separate issue, out of scope here.

## ⚪ Disagree / Intentional

- `.github/workflows/scorecard.yml:31` `[security]` · the action pins its container image by tag (`ghcr.io/ossf/scorecard-action:v2.5.0`), not digest · set upstream in `action.yaml`; the commit pin is the strongest control available here, accepted residual risk.

## Per-dimension summary

- Security: pin verified (annotated tag `v2.5.0` → commit `fa7117db…`); v2.5.0 pulls its image from `ghcr.io` instead of `gcr.io`, which removes the failing pull.
- Correctness: inputs used (`results_file`, `results_format: sarif`, `publish_results`) unchanged in the v2.5.0 release notes.
