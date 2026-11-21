# Local review — bb-homelab (feat/260-deploy-forgejo)

Pre-push review of the Forgejo service files, its Caddy site and its conception documents.

- Date: 2026-11-21
- Commit: 297f230 (round 1), fixes in the following commit
- Scope: branch diff `main...HEAD`
- Checks run: adversarial (fresh reviewer, 2 rounds) · design · docs · containers · CI mirror ·
  SonarQube · secrets. Tests: n/a (infrastructure repository, no test suite). Security and
  correctness: covered by the adversarial review and the diff read, no separate pass.
- Verdict: fix Must Have first · Must 2 · Should 12 · Nice 6

## Adversarial review (#236)

- Round 1 on `297f230`: Must 1 · Should 5 · Nice 5 · unverified 1 · Push gate: closed
- Round 2 on `333ff30`: 9 fixed · 2 not fixed (S3 deferred to the first-deploy tests, N2 accepted) · 0 regressed · new Must 0 · new Should 2 · new Nice 1 · **Push gate: open**
- Round 2 follow-up: the 2 Should (ADR 0011 sensitivity thresholds, ADR 0007 compose list) and the Nice (bootstrap creates `~/backups/forgejo`) are fixed in the commit that carries this line
- Round 3 on `84381c2`: 3 fixed · 0 not fixed · 0 regressed · new Must 0 · new Should 0 · new Nice 0 · **Push gate: open**
- ADR 0011: per-criterion scores of the three matrices confirmed by the owner on 2026-11-21
- Optional second review (owner's own account): not run (never a gate step)

## Pre-merge gate (pre-push run on 297f230)

| Step | Result |
|---|---|
| 0 CI mirror | ✅ markdownlint-cli2 0.13.0 (version bundled by the pinned Action): 0 error · ✅ yamllint (`.yamllint.yaml`) · ✅ shellcheck on every script · gitleaks: step 4 · hadolint: no Dockerfile changed · CI-only: CodeQL, dependency-review, Scorecard |
| 1 Tests | n/a: no test suite in this repository |
| 2 Coverage | n/a |
| 3 SonarQube | ✅ `QUALITY GATE STATUS: PASSED` |
| 4 Secrets | ✅ gitleaks clean (`main..HEAD`) · no tracked `.env` · diff read: nothing sensitive |
| 5 E2E/smoke | n/a in the repository. Manual smoke on the PC with the compose hardening: container healthy, uid 1000, read-only rootfs, admin CLI works, paused `docker cp` copy passes `PRAGMA integrity_check`. Trivy image scan (CRITICAL with a fix): 0 |

- Gate: **pre-push green** — every local check passed; the Pi deployment and the restore test
  come after the merge.
- Pre-merge run on `84381c2` (2026-11-21): markdownlint-cli2 0.13.0, yamllint and gitleaks
  (`main..HEAD`) re-run clean; SonarQube `QUALITY GATE STATUS: PASSED`; no shell or Dockerfile
  change since `297f230`. Steps 1, 2 and 5 stay n/a.

## 🔴 Must Have

- `storage/scripts/pull-backups.sh:26` `[adversarial]` · the new `backups/forgejo/` source did not
  exist on the Pi: `rsync` exits 23 and the PC's nightly pull alerts every night until the
  deploy · fixed (owner decision, 480/500): empty `~/backups/forgejo` created on the Pi on
  2026-11-21, logged in `PROJECT_LOG.md`.
- `services/forgejo/BACKUP.md` `[design]` · duplicated the shared procedure of
  `storage/APPDATA-BACKUP.md` and had already drifted (restore guard missing) · fixed (owner
  decision, 430/500): file deleted, Forgejo added to every section of the shared file, short
  "Sauvegarde" section in the service README.

## 🟡 Should Have

- `services/forgejo/README.md` (admin account) `[adversarial]` · the first account is not forced
  to change its password · fixed: `--must-change-password=true`.
- `services/forgejo/README.md` (bootstrap step 3) `[adversarial]` · a second run overwrote the
  secret key · fixed: an existing `.env` is left untouched.
- `docs/decisions/0011-forgejo-git-forge.md` `[adversarial|design|docs]` · "décrite et testée"
  overclaimed · fixed: the restore test is stated as due at the first deploy.
- `docs/decisions/0011-forgejo-git-forge.md` `[design]` · deviation from ADR 0007 (no loopback
  binding) not stated; ADR 0007 recovery note named "two compose files" · fixed in both ADRs.
- `docs/decisions/0011-forgejo-git-forge.md` `[design]` · tables showed totals only · fixed: full
  matrices with weights, scores and sensitivity.
- `services/forgejo/docker-compose.yml:21` `[adversarial]` (unverified) · the 64 MB `/tmp` tmpfs
  holds uploads in progress and merge copies · not changed: added to the first-deploy tests
  (README, `PROJECT_LOG.md`).
- `storage/OFFPI-COPY.md:16` `[adversarial]` · growth figure no longer true with Forgejo
  archives · fixed.
- `docs/architecture/diagrams/forgejo/08-deployment.md` `[docs|design]` · wrong backup node and
  LAN label · fixed.
- `network/README.md:40` `[docs]` · a dated survey listed a port not deployed yet · fixed: marked
  as planned.
- `services/forgejo/README.md` (SSH fingerprint) `[docs]` · the check must run from the Pi
  itself · fixed.
- `services/forgejo/README.md` (secret key) `[docs]` · wording contradicted the backup note ·
  fixed.
- `services/forgejo/README.md` `[docs|design]` · image tag repeated in an executable command ·
  fixed: the key comes from `openssl rand -hex 32`, the tag stays in the compose.

## 🔵 Nice to Have

- `services/uptime-kuma/README.md:79` `[adversarial|docs]` · "once deployed" qualifier · fixed.
- `services/forgejo/README.md` `[adversarial]` · `docker network create` not idempotent · fixed.
- `services/forgejo/README.md` `[adversarial|design]` · LFS off and uid/gid origin not
  documented · fixed.
- `services/homepage/config/services.yaml:17` `[adversarial]` · tile present before the deploy ·
  kept: the deploy follows the merge.
- `docker-compose.yml` `[containers]` · 512 MB may be tight · to watch after the deploy.
- `docs/architecture/diagrams/network-isolation/08-deployment.md` `[design]` · global diagram
  out of date · issue to file.

## ⚪ Disagree / Intentional

- `services/forgejo/docker-compose.yml:9` `[containers]` · pin the image digest · the repository
  pins tags through an `.env` variable (Caddy, Kuma, n8n, Vaultwarden); only Immich pins digests.
- `.github/dependabot.yml` absent `[containers]` · pre-existing, repository-wide, and it changes
  `.github/` · out of scope, issue to file with the owner's agreement.
- `AGENTS.md` `[adversarial]` · still allows AI attribution and Copilot review · pre-existing,
  out of scope, issue to file.

## Per-dimension summary

- Adversarial: one Must (nightly pull would fail), five Should on claims and bootstrap safety.
- Design: one Must (duplicated backup procedure), ADR completeness.
- Docs: no Must; diagram, dated survey and wording fixes.
- Containers: hardening conforms; Dependabot and digest pinning are repository-wide topics.
- Tests: n/a. Security and correctness: no separate pass.
