# Local review — bb-homelab (docs/222-n8n-workflow-inventory)

- Date: 2026-11-06
- Commit: 1fe88b9 (round 1 on 3333039)
- Scope: branch diff main...HEAD (`--push`)
- Checks run: adversarial (2 rounds) · docs (in the adversarial pass) · security (gitleaks + diff read) · lint (markdownlint)
- Verdict: ship (pre-push) · Must 0 open (1 fixed) · Should 1 deferred to #225 (5 fixed) · Nice 2 deferred to #225 (1 fixed)

## Adversarial review (#236)

- Round 1 on `3333039`: Must 1 · Should 6 · Nice 2 · unverified 3 · Push gate: closed
- Round 2 on `1fe88b9`: 8 fixed · 2 not fixed (deferred to #225) · 0 regressed · new Must 0 · **Push gate: open**
- Hosted reviewers (filled at the pre-merge run): pending

## Pre-merge gate (head SHA 1fe88b9)

| Step | Result |
|---|---|
| 0 CI mirror | markdownlint (MD060 only, known false positive, not run by the CI action) · gitleaks local · other PR jobs (shellcheck, yamllint, hadolint) have no file in scope · CodeQL, Scorecard, dependency-review CI-only |
| 1 Tests | n/a: docs-only diff, the repo holds no application code |
| 2 Coverage | n/a (docs-only repo deviation, `CLAUDE.md`) |
| 3 SonarQube | ⏸ deferred to the pre-merge run (`--push`) |
| 4 Secrets | ✅ gitleaks clean (main..HEAD) · no tracked .env · diff read: credential name and last four chat digits only |
| 5 E2E/smoke | n/a: no runtime change |

- Gate: `--push`: **pre-push green**, SonarQube deferred (never GREEN)

## 🔴 Must Have

- `services/n8n/README.md:3-6,83` `[adversarial]` · intro and security notes contradicted the inventory (Anthropic/GitHub credentials) · fixed in `1fe88b9`

## 🟡 Should Have

- `services/n8n/.env.example:23-27` `[adversarial]` · lists unused Anthropic/GitHub variables · deferred to #225
- Bot column, stopped tunnel, workflows paragraph, watchdog wording, workflow count, database copy deletion `[adversarial|docs]` · fixed in `1fe88b9`

## 🔵 Nice to Have

- `ARCHITECTURE.md:71` `[adversarial]` · workflow name not aligned · deferred to #225
- `services/n8n/README.md:109` `[adversarial]` · redundant parenthesis · deferred to #225
- `POST /webhook/feedback` path `[adversarial]` · fixed in `1fe88b9`

## ⚪ Disagree / Intentional

- `services/n8n/README.md` table `[docs]` · MD060 · known false positive (`docs-conventions.md`)
- French section in an English README `[docs]` · Category A is French (`docs-conventions.md`)

## Per-dimension summary

- Adversarial: one stale-claim Must fixed, gate open · Design / tests / containers: n/a (docs only) · Docs: covered by the adversarial pass · Security: clean · Correctness: claims cross-checked against PROJECT_LOG and ADR 0004
