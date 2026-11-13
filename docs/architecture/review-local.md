# Local review — bb-homelab (#224 Immich)

Pre-push review of the Immich branch: the push waits for the Must fixes and a second adversarial round.

- Date: 2026-11-13
- Commit: 06bbd9d
- Scope: branch diff origin/main...HEAD (`--push`)
- Checks run: adversarial (Opus, round 1) · docker · docs · lint · secrets · SonarQube · Trivy
- Verdict: ship (pre-push) · Must 0 open · Should 0 open · Nice 0 open (round 1: Must 7 · Should 10 · Nice 9)

## Adversarial review (#236)

- Round 1 on `06bbd9d`: Must 7 · Should 10 · Nice 9 · unverified 3 · Push gate: closed
- Round 2 on `4a7515a`: 7 Must fixed (M7 by owner decision C) · 0 regressed · new Should 3 (fixed in the next commit: Caddy network note, two matrices, #250 and #251) · **Push gate: open**
- Optional second review (owner's OpenAI account): not run

## Pre-merge gate (head SHA 06bbd9d)

| Step | Result |
|---|---|
| 0 CI mirror | shellcheck rc 0 · yamllint rc 0 (line-length warnings) · markdownlint 0 errors (MD060 tolerated) |
| 1 Tests | n/a (no application code, see CLAUDE.md deviations) · `docker compose config` OK · dump/restore run in scratch OK |
| 2 Coverage | ⏸ deferred to the pre-merge run (`--push`) |
| 3 SonarQube | ✅ PASSED |
| 4 Secrets | ✅ gitleaks clean (origin/main..HEAD) · no tracked .env · diff read: nothing sensitive |
| 5 E2E/smoke | ⏸ deferred: Pi deploy after merge |

- Gate: `--push`: **not green** — Trivy CRITICAL on 3 images, 7 Must open

## 🔴 Must Have

- `docs/decisions/0010-immich-screenshot-source.md:85-116` `[adversarial|docs]` · six MCDA totals wrong (Stockage B 360, C 325; Accès B 330; Cible A 380, B 335, C 340); winners unchanged, Cible C now above B · fix the cells, tell the owner.
- `docker-compose.yml:41`, ADR 0010:41,90, `README.md:72-73`, `02-sequence.md:39` `[adversarial|docs]` · Immich v3.4.1 has no night window for OCR: OCR runs at upload · owner decision 2026-11-13: option A, OCR at upload, docs aligned.
- `02-sequence.md:44` `[adversarial|docs]` · `pg_dumpall` vs script `pg_dump` · align with the dump decision below.
- `01-deployment.md:11-14,58` `[adversarial|docs]` · "encore à décider" and "réseau interne" are false · delete / reword.
- `network/README.md:34-42` `[adversarial]` · port 2283 missing from the exposure table; 22/tcp now used from the LAN · add rows.
- ADR 0010:123-127 vs `docs/security/AUDIT.md:128` (#141) `[adversarial|security]` · #141 would make SSH tailnet-only and break the mirror · add the consequence, update AUDIT R13, comment #141, `from=` on the key.
- `services/immich/docker-compose.yml:9,45,83` `[adversarial|docker]` · Trivy CRITICAL fixable: server 2, ML 2, Postgres 20 · owner decision 2026-11-13: option C, wait for fixed upstream images; Pi deploy suspended (ADR 0010, README).

## 🟡 Should Have

- `BACKUP.md:39` `[adversarial|security]` · Kuma push URL in the crontab · read it from `~/.config/bb-homelab/kuma-push-immich` like n8n.
- `bb-homelab-immich-pull-failed.service:6` `[adversarial]` · `notify-send` has no bus under linger: silent failure · Pi-side freshness probe or record the gap.
- `BACKUP.md:44-63` `[adversarial]` · BatchMode with no known host key; passphrase prompt · `-N ''` + host-key step.
- `BACKUP.md:104-107` `[adversarial]` · restore races the initdb server · `up -d --wait database`.
- `BACKUP.md:12`, `db-dump.sh:42` `[adversarial]` · `pg_dump` drops `ALTER DATABASE` settings; upstream uses `pg_dumpall` · owner decision.
- ADR 0010:3 `[docs]` · `Proposed` → `Accepted`.
- ADR 0010:76-117 `[adversarial]` · no sensitivity check · add one line per close matrix.
- `docs/architecture/diagrams/immich/*` `[adversarial]` · names break `conception-naming` · rename to 08/02-…/07-… and fix links.
- `docker-compose.yml:7-38,107-114` `[adversarial|docker]` · server without `cap_drop`; backend not internal · try `cap_drop: [ALL]`, internal backend + ML egress network.
- ADR 0007:58-62 `[adversarial]` · a third hard-coded tailnet IP · add a consequence.

## 🔵 Nice to Have

- ADR 0010:28 · wrong source (ADR 0002 → `vaultwarden/CLIENTS.md:137`).
- ADR 0010:124 · the Pi is on Ethernet, not Wi-Fi.
- `02-sequence.md:51` · rsync goes to sshd + rrsync, not immich-server.
- `README.md:43-44` · missing `chmod 700` on `db-dumps`.
- `docker-compose.yml:47-48` · ML gets `DB_PASSWORD` through `env_file`.
- `docker-compose.yml:7` · `IMMICH_TRUSTED_PROXIES` excludes Caddy's bridge IP.
- `bb-homelab-immich-pull.service:12` · `RestartMode=direct` needs systemd ≥ 254.
- `pull-immich.sh:20` · avahi dependency not recorded; also the wrong `--backup-dir` comment.
- `services/README.md:20` · French label among English rows.

## ⚪ Disagree / Intentional

- `README.md:83-90` · `asset.delete` on the API key: accepted risk, ADR 0010 decision 7.
- `docker-compose.yml:16-17` · two ways in (port + Caddy): ADR 0007 / Jellyfin precedent.
- `docker-compose.yml:64-77` · Valkey without volume: queue only, as upstream.
- `docker-compose.yml:7` · `IMMICH_TRUSTED_PROXIES` default `uniquelocal` covers RFC 1918 (proxy-addr), so Caddy's bridge IP is trusted.
- `docker-compose.yml:37-38` · `healthcheck: disable: false` is enough: the server image declares `immich-healthcheck` (checked on the pinned digest).
- docker-auditor: Dependabot and Trivy CI jobs: owner rule 2026-11-07, local tools only (#90, #130).

## Per-dimension summary

- Adversarial: 7 Must, mostly doc truth and Trivy · Docker: healthcheck, cap_drop, PG14 EOL follow-up · Docs: diagrams and ADR drift · Security: #141 conflict, Kuma token in crontab · Correctness: scripts run clean end to end.
