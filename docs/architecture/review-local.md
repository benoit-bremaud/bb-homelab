# Local review — bb-homelab (fix/200-per-backend-proxy-networks)

- Date: 2026-11-05
- Commit: 2228f2f (polish after round 3); round 1 on 533eff6, round 2 on f228f00, round 3 on
  a835e56
- Scope: branch diff `main...HEAD` (one proxy network per backend: compose files of Caddy and
  the five backends, `Caddyfile` `tailnet_only` snippet, ADR 0009, ADR 0002 status, deployment
  diagram `network-isolation/08-deployment.md`, service READMEs, skills `infra-patterns` and
  `new-service`, `PROJECT_LOG.md`)
- Checks run: adversarial (3 rounds) · design · docker · docs · security (diff read, gitleaks) ·
  CI mirror (markdownlint, yamllint, `docker compose config`); tests not applicable (no
  application code)
- Verdict: ship as-is · Must 0 · Should 0 · Nice 0 open · 1 deferred to #217

## Adversarial review

- Round 1 on `533eff6`: Must 3 (docs) · Should 8 · Nice 5 · Push gate: closed
- Round 2 on `f228f00`: 11 of 13 fixed · 1 regressed (`root.crt` check needs `sudo`) ·
  new Must 2 · Should 8 · Nice 4 · Push gate: closed
- Round 3 on `a835e56`: every round 2 item fixed (Nice 4 not applied, accepted) · Must 0 ·
  Should 1 · Nice 4 · **Push gate: open**
- Round 3 Should and Nice fixed in `2228f2f` (wording only)
- Hosted automated reviews (filled at the pre-merge run): pending

## Deferred and accepted

- Pin the `edge` subnet and restrict the Kuma `/api/push/*` exemption to its gateway: needs a
  free subnet chosen on the Pi; tracked in #217, cited in ADR 0009 and `PROJECT_LOG.md`.
- Docker Engine ≥ 28 for `gw_priority`: not documented (unverified); the Pi runs Docker 29.
- `Bascule et retour arrière` placed after Refs in ADR 0009: an extra trailing section, allowed
  by `docs-conventions.md` (the required sections keep their order).

## Pre-merge gate (head SHA 2228f2f)

| Step | Result |
|---|---|
| 0 CI mirror | ✅ markdownlint 0 error on the changed files (MD060 known false positive) · yamllint 0 error (line-length warnings, one pre-existing) · `docker compose config -q` passes for Caddy and Uptime Kuma · shellcheck, hadolint: no file in scope · CodeQL, Scorecard, dependency review: CI-only |
| 1 Tests | n/a: no application code; Caddy matchers adapted offline with `caddy:2.11.7` |
| 2 Coverage | n/a: project deviation in `CLAUDE.md` |
| 3 SonarQube | ⏸ deferred to the pre-merge run |
| 4 Secrets | ✅ gitleaks clean (`main..HEAD`) · no tracked `.env` · diff read: no secret, no AI tool name in docs |
| 5 E2E/smoke | ⏸ manual on the Pi with the owner: cutover steps of ADR 0009, then card LATERAL by IP |

## Out of scope (pre-existing)

- The `{ …; exit 1; }` guards in service READMEs close an interactive SSH shell when pasted.
- `services/caddy/README.md` is in English although `services/*/README.md` is Category A
  (French).
