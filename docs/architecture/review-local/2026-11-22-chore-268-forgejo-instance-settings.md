# Local review — bb-homelab (branch diff origin/main...HEAD)

- Date: 2026-11-22
- Commit: 652959f
- Scope: branch `chore/268-forgejo-instance-settings`, 10 files (Forgejo compose, docs, log)
- Checks run: adversarial (fresh reviewer, 3 rounds) · docker · docs · security (gitleaks, diff read) · correctness (throwaway Forgejo 15.0.12 runs)
- Verdict: ship as-is · Must 0 · Should 2 · Nice 0

## Adversarial review (#236)

- Round 1 on `16b47dc`: Must 3 · Should 8 · Nice 4 · unverified 4 · Push gate: closed
- Round 2 on `154018f`: 13 fixed · 1 partly fixed (S6) · 0 regressed · new Must 1 · Push gate: closed
- Round 3 on `652959f`: Must fixed · new Must 0 · **Push gate: open**
- Optional second review (owner's own account): not run (never a gate step)

## Pre-merge gate (head SHA 652959f)

| Step | Result |
|---|---|
| 0 CI mirror | ✅ markdownlint-cli2 0.13.0 (bundled by action v16) on the 10 files: 0 error · yamllint on the compose: exit 0 · gitleaks: no leak · hadolint, shellcheck: no Dockerfile or shell script in the diff (n/a) · CodeQL, Scorecard, dependency-review: CI-only |
| 1 Tests | n/a: no code; `docker compose config -q` passes; settings exercised on a throwaway local 15.0.12 instance (title, session kept after restart, 2FA enforced, forced-private repositories, admin `PATCH` to public) |
| 2 Coverage | n/a (configuration and documents only) |
| 3 SonarQube | ✅ PASSED on `16b47dc` (project `bb-homelab`; later commits change Markdown only, excluded by `sonar.exclusions=**/*.md`, plus compose comments) |
| 4 Secrets | ✅ gitleaks clean (`origin/main..652959f`) · no tracked .env · diff read: token name and file path only, no value |
| 5 E2E/smoke | ⏸ applied on the Pi after the merge (`git pull`, `docker compose up -d`), then health, title, session after restart, API repository private |

- Gate: `--push` **pre-push green** — 5 deferred to the Pi apply after merge; no `scripts/attest.sh`, so the merge needs the owner's yes (`MERGE_GATE_WAIVER`)

## 🔴 Must Have

_None._

## 🟡 Should Have

- `services/forgejo/README.md:203` `[adversarial]` · Token rotation reminder (2027-11) only in prose · file a dated issue and link it from the README and the log.
- `services/n8n/BACKUP.md:198`, `services/vaultwarden/BACKUP.md:231` `[adversarial]` · Pre-existing: `sqlite3` run on the Pi host, where it is absent · follow-up issue, same read-only `python3` check.

## 🔵 Nice to Have

_None._

## ⚪ Disagree / Intentional

- `docs/decisions/0011-forgejo-git-forge.md:106,112` `[adversarial]` · Stale wording kept: ADRs are superseded, never rewritten (`.claude/rules/docs-conventions.md`); the log records it.
- `services/forgejo/docker-compose.yml` `DEFAULT_PRIVATE` next to `FORCE_PRIVATE` `[docker]` · Redundant but harmless: keeps the web form consistent; owner-approved setting.
- `DEFAULT_USER_VISIBILITY=private` `[docker]` · Single-account instance: hiding accounts from each other costs nothing today.

## Per-dimension summary

- Adversarial: 3 rounds, gate open. · Docker: 0 Must, comment placement fixed. · Docs: 0 Must, 6 Should fixed. · Security: no secret, admin-token residual risk recorded. · Correctness: four claims verified on a throwaway instance.
