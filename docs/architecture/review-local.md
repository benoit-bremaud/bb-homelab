# Local review — bb-homelab (branch `docs/46-security-audit`)

- Date: 2026-10-23
- Commit: 9f64e44 (round 1) → fixes in dd47194
- Scope: branch diff `origin/main...HEAD` — `docs/security/AUDIT.md`
  (new, Category A, French) and one navigation row in `README.md`
- Checks run: docs · correctness · security · `--push` mode (no QA pass;
  docs-only diff, no runtime touched)
- Verdict (round 1): fix Must Have first · Must 3 · Should 6 · Nice 3 ·
  Disagree 0 — **all Must and Should resolved before push** (dd47194)

## Pre-merge gate (head SHA dd47194)

| Step | Result |
|---|---|
| 1 Tests | N/A — pure docs diff, no application code in this repo (stated per AGENTS.md §4) |
| 2 Coverage | tests N/A · docs: the new document has no public API; every section is filled, no TODO left except the mosquitto Docker Hub check, dated and owned by the R12 issue |
| 3 SonarQube | ✅ `QUALITY GATE STATUS: PASSED` (project `bb-homelab`, local server, run on 9f64e44; dd47194 changes prose only in the same file) |
| 4 Secrets | ✅ gitleaks `origin/main..HEAD` no leaks · no tracked `.env*` beyond `.env.example` · diff read: only the Tailscale IP already present in `README.md` and `services/caddy/README.md` |
| 5 QA pass | skipped (`--push` mode); linters: markdownlint clean except MD060 (tolerated false positive), links verified by hand |

- Gate: **GREEN for push** — the merge gate re-runs step 3 on the final SHA

## 🔴 Must Have

- `docs/security/AUDIT.md:91` `[docs|correctness]` · R8 scored 2×4 = 8 but was tagged P2 (threshold ≥ 9) · **fixed**: P3, and §5.2 keeps it under #131
- `docs/security/AUDIT.md:91` `[docs|correctness]` · "six conteneurs sur sept" root contradicted the §3 table (five of seven: n8n is `node`, cloudflared `nonroot`) · **fixed**: "cinq des sept"
- `docs/security/AUDIT.md:113` `[docs]` · §5.2 titled "P3/P4" while listing R7 (P2) · **fixed**: retitled, R7 marked P2 with the reason it is deferred, step 5 states the partial Kuma backup

## 🟡 Should Have

- `docs/security/AUDIT.md:107-108` `[docs]` · roadmap treated P2 items before the P1 cloudflared · **fixed**: step 3 = the two exposed edges (cloudflared, Caddy), step 4 = Vaultwarden + n8n
- `docs/security/AUDIT.md:123` `[correctness]` · "`harden-ssh.sh` désactive X11" was false (no X11 handling in the script) · **fixed**: "ajouter `X11Forwarding no`"
- `docs/security/AUDIT.md:69,119` `[correctness]` · Jellyfin 8096 is published on purpose (ADR 0003, clients without the local CA) · **fixed**: stated in §3, R10 and §5.2
- `docs/security/AUDIT.md:134,143` `[docs]` · ports 18555/18554/39295 orphaned in §6 · **fixed**: resolved by the sudo pass (go2rtc, cloudflared) and tied to R10
- `docs/security/AUDIT.md:148` `[docs]` · #47 and #134 listed without being cited · **fixed**: reference list rewritten
- `docs/security/AUDIT.md:23` `[docs]` · "aucune redirection box documentée" was not evidence · **fixed**: replaced by the UFW relevé

## 🔵 Nice to Have

- `docs/security/AUDIT.md:59` `[docs]` · mosquitto "à vérifier" without owner or date · **fixed**: tied to the R12 issue
- `docs/security/AUDIT.md:88` `[docs]` · Vaultwarden security claim without a source · **fixed**: link to the release notes
- `docs/security/AUDIT.md:56` `[docs]` · mixed gap units (years vs minors) · **fixed**: "26 mois de publications"

## ⚪ Disagree / Intentional

_None._

## Per-dimension summary

- Design: N/A (document) · Docs: 3 internal inconsistencies, all fixed · Tests: N/A · Security: nothing sensitive in the diff; the sudo relevés (UFW, sshd -T, ss) are summarised, not pasted raw · Correctness: image tags, ports, routes, workflow list and link targets verified against the repo
