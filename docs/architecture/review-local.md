# Local review — bb-homelab (fix/201-bump-images-critical-cves)

- Date: 2026-11-05
- Commit: a288ed8
- Scope: branch diff main...HEAD (`--push`)
- Checks run: adversarial (Opus, round 1) · containers (docker-auditor) · security (gitleaks + diff read) · lint (CI versions)
- Verdict: fix Must Have first · Must 5 · Should 7 · Nice 2

## Adversarial review (#236)

- Round 1 on `a288ed8`: Must 3 · Should 5 · Nice 2 · unverified 1 · Push gate: closed
- Round 2: pending (after the fix commit)
- Hosted reviewers (filled at the pre-merge run): pending

## Pre-merge gate (head SHA a288ed8)

| Step | Result |
|---|---|
| 0 CI mirror | ✅ markdownlint-cli2 0.13.0 (action v16) 0 errors · ✅ yamllint (2 pre-existing line-length warnings) · ✅ shellcheck · ✅ gitleaks · CodeQL, Scorecard, dependency-review CI-only · hadolint n/a (no Dockerfile) |
| 1 Tests | n/a (no application code; repo deviation in CLAUDE.md) |
| 2 Coverage | n/a (same deviation) |
| 3 SonarQube | ⏸ deferred to the pre-merge run (`--push`) |
| 4 Secrets | ✅ gitleaks clean (main..HEAD) · no tracked .env · diff read: nothing sensitive |
| 5 E2E/smoke | ⏸ deferred: Pi redeploy + Uptime Kuma green after merge |

- Gate: `--push`: **not green** — Must open

## 🔴 Must Have

- `docs/architecture/diagrams/network-isolation/08-deployment.md:34,37,43,46` `[adversarial|containers]` · deployment diagram keeps the old tags · update the four image nodes.
- `.trivyignore.yaml:71-77` `[adversarial]` · protobufjs is reachable (Kuma gRPC Keyword monitor parses a user-supplied proto) · rewrite as reachable by an admin, note no gRPC monitor exists (Pi check: http/port/push only), shorten expiry.
- `.trivyignore.yaml:4-5`, `PROJECT_LOG.md` `[adversarial]` · documented scan command lacks `--exit-code 1`, so it never fails · use one identical command with `--exit-code 1 --ignorefile`.
- `.trivyignore.yaml` (11 entries) `[containers]` · no follow-up issue per waiver · open one review issue and cite it in each statement.
- `.trivyignore.yaml` (all entries) `[containers]` · skill requires `paths`, entries use `purls` · owner decision.

## 🟡 Should Have

- `PROJECT_LOG.md` `[adversarial]` · Uptime Kuma count is 5, total 12 waivers.
- `.trivyignore.yaml:16-24` `[adversarial]` · Jellyfin is also published directly on the tailnet IP :8096; state it.
- `.trivyignore.yaml:52-53` `[adversarial]` · Jellyfin brotli is loaded via libfreetype6/libcurl; "Low risk", not "Not reachable".
- `.trivyignore.yaml:98-100` `[adversarial|containers]` · n8n Node bundles brotli; real paths are git/libcurl and graphicsmagick/freetype.
- `PROJECT_LOG.md` `[adversarial]` · rollout note: Pi `.env` tag overrides, cold backups before n8n and Vaultwarden (SQLite migration).
- `services/uptime-kuma/README.md:10` `[containers]` · rollback line for `-slim`.
- `.trivyignore.yaml:78-84` `[adversarial|containers]` · tar is build-time only (`extra/download-dist.js`).

## 🔵 Nice to Have

- `.trivyignore.yaml:1-8` `[containers]` · record Trivy version and DB date (0.76.1, 2026-11-05).
- `.trivyignore.yaml:89-91` `[adversarial]` · name curl as the Kuma libbrotli1 consumer.

## ⚪ Disagree / Intentional

- `services/n8n/docker-compose.yml:9` `[adversarial]` · minor bump, owner MCDA decision (430/500).
- `services/uptime-kuma/docker-compose.yml:6` `[adversarial]` · `-slim` variant, owner decision after Pi check.
- `.trivyignore.yaml:12-26` `[adversarial]` · reachable ASP.NET waivers, owner MCDA decision tied to #142.
- Compose digests, non-root users `[containers]` · out of the diff; Dependabot compose is #130.

## Per-dimension summary

- Adversarial: three Must (stale diagram, false protobufjs claim, scan never fails) · Containers: waiver format (`paths`, follow-up issue) · Security: clean · Lint: clean on CI versions.
