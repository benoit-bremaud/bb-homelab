# Local review — bb-homelab (branch diff origin/main...HEAD)

- Date: 2026-11-04
- Commit: 3194246 (round 3), round 1 on aa636e2, round 2 on af0c173
- Scope: branch `docs/207-pentest-session-2-report`, diff `origin/main...HEAD` (pentest report,
  plan, security README, `PROJECT_LOG.md`, `.gitignore`)
- Checks run: adversarial (2 rounds) · docs · security (diff read, gitleaks) · CI mirror
  (markdownlint); design, tests and containers not applicable (documentation only)
- Verdict: ship as-is · Must 0 · Should 0 · Nice 0 open

## Adversarial review

- Round 1 on `aa636e2`: Must 2 · Should 7 · Nice 3 · unverified 0 · Push gate: closed
- Round 2 on `af0c173`: 13 fixed · 0 not fixed · 0 regressed · new Must 0 · new Should 1 ·
  new Nice 2 · Push gate: open
- Round 3 on `3194246`: 3 fixed · 0 not fixed · 0 regressed · new Must 0 · **Push gate: open**
- Hosted reviewers (filled at the pre-merge run): Copilot pending · Codex optional

## Pre-merge gate (head SHA 3194246)

| Step | Result |
|---|---|
| 0 CI mirror | ✅ markdownlint (4 changed `.md` files, MD060 known false positive); yamllint, shellcheck, hadolint: no file in scope; CodeQL, Scorecard, dependency review: CI-only |
| 1 Tests | n/a — documentation only, no test suite in the repository |
| 2 Coverage | n/a — no code; docs coverage replaced by linters (project deviation in `CLAUDE.md`) |
| 3 SonarQube | ⏸ deferred to the pre-merge run (`--push`) |
| 4 Secrets | ✅ gitleaks clean (`origin/main..HEAD`) · no tracked `.env` · diff read: no address, tailnet or tunnel name, token, or tool name; `docs/security/scope.yaml*` gitignored |
| 5 E2E/smoke | n/a — no runnable product in the diff |

- Gate: `--push`: **pre-push green**, SonarQube deferred (never GREEN)

## 🔴 Must Have

- `docs/security/reports/2026-11-04-pentest.md:3` `[adversarial|docs]` · lead contradicted the
  body (active cards had run) · rewritten — fixed in af0c173
- `docs/security/reports/2026-11-04-pentest.md:68` `[adversarial]` · total Critical CVE counts
  labelled fixable · fixable / total counts from #201 — fixed in af0c173
- `docs/security/pentest-plan.md:22` `[docs]` · E1 claimed an outside scan on 2026-11-03 ·
  "outside scan not done" — fixed in af0c173

## 🟡 Should Have

- T2 and OSINT overstated as done; `ssh-audit`, Shodan and the T2 remainder untracked; Info
  finding without an issue; scope file undocumented; no `Refs` line in `PROJECT_LOG.md`; stale
  "tailnet scan done" in `PROJECT_LOG.md` · all fixed (af0c173 and the report commit), #207
  updated
- Shared test IDs missing from the home-assistant plan header · tracked in
  home-assistant#97

## 🔵 Nice to Have

- EXT-APP risk, risk-scale mapping, `.gitignore` backup pattern, report lead wording,
  `PROJECT_LOG.md` list of open items · all fixed

## ⚪ Disagree / Intentional

- New IDs H9–H12 and P5 overlap hub tests in substance · intentional per-repository scope split
  (home-assistant#95), with the shared header tracked in home-assistant#97

## Per-dimension summary

- Adversarial: two Musts in round 1, all findings fixed, gate open in round 2 · Docs: one Must
  (E1), consistency fixes applied · Security: no leak, scope file kept out of git · Design,
  tests, correctness: not applicable to a documentation-only diff
- Out of scope, pre-existing: the dead tunnel name in the public issue #143 and the login
  account name in `docs/security/pentest-plan.md`
