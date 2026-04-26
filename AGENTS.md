# AGENTS.md

> **Optional personal extension**: the maintainer keeps a machine-local cross-agent rules file at `~/.agent-rules/common.md` (question & answer pattern with "need more explanation" option, language rules, decision traceability). It is **not** required to follow this repo — agents and contributors should treat the file below as fully self-contained. If the personal file is present in your environment, read it for additional context; otherwise proceed with this document alone.

Shared instructions for any AI coding agent (or human contributor) working in this repository. This file is agent-agnostic by design: it depends on no specific tooling. If you are a new agent picking up this project, read this file first, then follow its links.

## 1. What this project is

`bb-homelab` is a self-hosted homelab running on a Raspberry Pi 5, designed to remain hardware-agnostic. It orchestrates containerised services (n8n today; Jellyfin, reverse proxy, monitoring planned) with a strong security and reproducibility posture.

- Repo visibility: **private**. Do not assume public-release invariants yet — the public checklist in [CONTRIBUTING.md](CONTRIBUTING.md) must pass first.
- License: CC BY-SA 4.0 (see [LICENSE](LICENSE)).

## 2. Authoritative documents (read these, in order)

1. [README.md](README.md) — entry point and quick links.
2. [ARCHITECTURE.md](ARCHITECTURE.md) — 6-layer DIP architecture. Every change must fit a layer.
3. [CONTRIBUTING.md](CONTRIBUTING.md) — **source of truth** for branching, Conventional Commits, PR template, review procedure, security checklist, required CI checks.
4. [PROJECT_LOG.md](PROJECT_LOG.md) — chronological operational journal. Read the last entries for current state; update after every merge.
5. [docs/decisions/](docs/decisions/) — Architectural Decision Records (ADRs). Add a new ADR for any non-trivial architectural choice.

If this file and CONTRIBUTING.md disagree, CONTRIBUTING.md wins.

## 3. Layered architecture (DIP)

Changes must land in the correct layer. Higher layers depend on lower layers, never the reverse.

| Layer | Directory | Scope |
|---|---|---|
| 1 — Data persistence | [storage/](storage/) | Disks, mounts, SMART, backups |
| 2 — Network / remote access | [network/](network/) | Tailscale, tunnels, routing |
| 3 — Host / OS | [bootstrap/](bootstrap/) | Pi OS setup, SSH hardening, Docker install |
| 4-6 — Orchestration, packaging, service logic | [services/](services/) | Per-service `docker-compose.yml` + scripts |

When adding something, ask: which layer does it belong to? If unclear, write an ADR before coding.

## 4. Workflow rules (non-negotiable)

### Branching & commits

- Branch from `main`: `<type>/<issue-number>-<slug>` (e.g. `feat/14-caddy-reverse-proxy`).
- Never commit to `main` directly.
- Conventional Commits: `<type>(<scope>): <short description>`.
- All commit messages, code comments, and docs in **English**.

### Pull requests

- Open a PR with the template from CONTRIBUTING.md. End the body with `Closes #<issue>`.
- Add the PR to the project board, assign labels, assignee, milestone — see the API recipe in the user's global instructions.
- **Never merge autonomously.** Full gate:
  1. All required CI checks green.
  2. Automated reviewer (Copilot) has **posted** its review (requested ≠ posted).
  3. Every review comment addressed inline with priority (Must / Should / Nice / Disagree).
  4. Present a merge-readiness summary to the human.
  5. Wait for explicit human approval.
  6. Only then `gh pr merge --squash --delete-branch`.
- Never use `--auto` or `--admin` unless the human explicitly asks.
- Do not resolve review conversations programmatically — that is the human's action.

### Post-merge cleanup

```bash
git checkout main && git pull
git branch -d <branch>
git remote prune origin
```

Then append a dated entry to [PROJECT_LOG.md](PROJECT_LOG.md) referencing the PR number.

## 5. CI checks

Nine workflows live in [.github/workflows/](.github/workflows/). Actions are pinned by SHA.

Required on `main` (branch protection): `gitleaks`, `shellcheck`, `hadolint`, `markdownlint`, `yamllint`. Also run but not yet required: `sonarcloud`. Public-only (gated by visibility): `codeql`, `dependency-review`, `scorecard`.

Run locally before pushing:

```bash
shellcheck bootstrap/*.sh services/**/scripts/*.sh
npx -y markdownlint-cli2 '**/*.md'
yamllint .
hadolint services/**/Dockerfile   # when a Dockerfile exists
```

Never skip a required check with `--no-verify`, `--admin`, or by editing branch protection. If a check flakes, fix the root cause.

## 6. Common operational commands

### Deploy / manage n8n ([services/n8n/](services/n8n/))

```bash
cd services/n8n
cp .env.example .env
sed -i "s|^N8N_ENCRYPTION_KEY=.*|N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)|" .env
docker compose up -d
docker compose ps
docker compose logs cloudflared   # shows the ephemeral public URL
```

### Backup n8n volume (atomic, container-quiesced)

See [services/n8n/BACKUP.md](services/n8n/BACKUP.md). Script:

```bash
services/n8n/scripts/backup.sh
BACKUP_DIR=/mnt/backup/n8n KEEP=14 services/n8n/scripts/backup.sh
```

### Host bootstrap (Pi, one-time per machine)

See [bootstrap/FIRSTBOOT.md](bootstrap/FIRSTBOOT.md). Scripts are idempotent.

```bash
sudo bash bootstrap/bootstrap.sh
sudo bash bootstrap/harden-ssh.sh
sudo SSH_UFW_SCOPE=tailscale bash bootstrap/harden-ssh.sh   # Tailscale-only SSH
bash network/install-tailscale.sh
```

There is no top-level `Makefile`, `package.json`, or build system — each service is self-contained.

## 7. Security invariants

- **Private-first.** Do not flip visibility to public. The checklist (gitleaks on full history, no secrets in tracked files, rotated credentials, CI secret detection) lives in CONTRIBUTING.md and must pass first.
- **No secrets in git.** `.env` and `.env.*` are gitignored. `.env.example` carries placeholders only. Credentials for n8n workflows live in the n8n UI, not in `.env`.
- **No AI attribution anywhere in tracked files.** No `Co-Authored-By` AI lines, no "generated with …" in PR bodies, commit messages, README, or comments. This applies to every agent — including this one.
- Never force-push to `main` or `master`. Never commit `.env`, `*.pem`, `*.key`, `*.crt`.

## 8. Image and tooling pins

Service images are pinned in each `.env.example` (e.g. `N8N_IMAGE_TAG`, `CLOUDFLARED_IMAGE_TAG`). Bump deliberately via a dedicated PR — never silently.

## 9. PROJECT_LOG discipline

[PROJECT_LOG.md](PROJECT_LOG.md) is the operational journal, not a changelog. Every merged PR, architectural decision, or backlog change gets a dated entry. Convert relative dates to absolute (`Thursday` → `2026-04-23`) so entries stay interpretable later.

## 10. When you are unsure

- Read ARCHITECTURE.md + the relevant layer's `README.md`.
- Search [docs/decisions/](docs/decisions/) for a matching ADR.
- If still unclear, open an issue or ask the human — do not guess.
