# Local review — bb-homelab (PR #253, fix/131-harden-caddy)

- Date: 2026-11-18
- Commit: cbdc780
- Scope: branch diff `origin/main...HEAD` (`services/caddy/docker-compose.yml`,
  `services/caddy/README.md`, `storage/APPDATA-BACKUP.md`)
- Checks run: adversarial (fresh reviewer, 3 rounds) · containers · docs ·
  security · correctness (design and tests: n/a, no application code)
- Verdict: ship · Must 0 · Should 4 (3 fixed) · Nice 5

## Adversarial review (#236)

- Round 1 on `7169657`: Must 0 · Should 2 · Nice 3 · unverified 1 ·
  Push gate: open
- Round 2 on `96c277c`: 2 fixed · 0 not fixed · 0 regressed · new Should 1 ·
  Push gate: open
- Round 3 on `cbdc780`: all Should fixed · new Must 0 · **Push gate: open**
- Optional second review (owner's own account): not run

## Pre-merge gate (head SHA cbdc780)

| Step | Result |
|---|---|
| 0 CI mirror | ✅ yamllint (`.yamllint.yaml`) · ✅ markdownlint-cli2 0.13.0 (bundled by the v16 action) · ✅ gitleaks · hadolint, shellcheck: n/a (no Dockerfile or script) · CodeQL, Scorecard, dependency-review: CI-only |
| 1 Tests | n/a (no application code; `docker compose config` OK; caddy 2.10.2 to 2.11.9 start with the new options; real Caddyfile on an existing PKI: running, 0 errors, CA unchanged) |
| 2 Coverage | n/a (project deviation in `CLAUDE.md`: linters and config validation replace coverage) |
| 3 SonarQube | ✅ PASSED on `d1bd07e` (first two runs failed: disk 95 % full, Elasticsearch read-only; re-run at 87 %) |
| 4 Secrets | ✅ gitleaks clean (`--log-opts=--all`) · no tracked `.env` · diff read: nothing sensitive |
| 5 E2E/smoke | n/a locally; runtime check on the Pi after merge (health, `/proc/1/status`, HTTPS on each site) |

- Gate: **GREEN on `d1bd07e`** (no `scripts/attest.sh`: merge on the owner's explicit yes)

## 🔴 Must Have

_None._ (SonarQube gate fixed by the re-run)

## 🟡 Should Have

- `storage/APPDATA-BACKUP.md:124` `[docs]` · the Caddy sentence sits inside the
  `docker cp` paragraph, so the next sentence reads as Caddy-specific · move it
  to its own paragraph and link the Caddy README · **fixed**
- `services/caddy/docker-compose.yml:9` `[docs]` · the `0:0` ownership
  consequence is missing next to the code · add one comment line · **fixed**
- `services/caddy/README.md:237` `[containers|docs]` · "dans des PR suivantes"
  has no tracking link · point to #131 · **fixed**
- `services/caddy/docker-compose.yml:9` `[containers]` · no runtime evidence on
  the Pi yet · record `CapEff`/`NoNewPrivs`, health and HTTPS after deploy
  (planned in the PR's deploy section)

## 🔵 Nice to Have

- `docs/security/AUDIT.md:93` `[adversarial]` · R8 progress note
- `services/caddy/README.md:225` `[adversarial|docs]` · subsection instead of a
  long bullet
- `services/caddy/docker-compose.yml:9` `[docs]` · rationale repeated in three
  files; keep the detail in the README
- `storage/APPDATA-BACKUP.md:122` `[containers]` · post-restore check
  `stat -c '%u:%g' /mnt/appdata/caddy/data` should print `0:0`
- `services/caddy/docker-compose.yml:12` `[containers]` · the
  `ip_unprivileged_port_start=0` claim depends on the Docker version; cite it

## ⚪ Disagree / Intentional

- `services/caddy/docker-compose.yml:18` `[containers]` · "test the rollback
  with no-new-privileges": already done (2.10.2 and 2.11.7 start with
  `cap_add: NET_BIND_SERVICE`, adversarial round 1)
- `storage/APPDATA-BACKUP.md:91` `[docs]` · MD060 on table dividers: known
  false positive, line unchanged
- `docs/security/AUDIT.md` §3 stale: update deferred until #131 closes
- No `PROJECT_LOG.md` entry: logged in a separate `docs(log)` PR after merge

## Per-dimension summary

- Adversarial: 3 rounds, gate open, nothing left but two optional Nice items
- Containers: conformant for a partial step; runtime evidence on the Pi needed
- Docs: accurate; two structure fixes
- Security: the change reduces privileges; nothing sensitive in the diff
- Correctness: compose renders; Caddy starts on every tested tag
