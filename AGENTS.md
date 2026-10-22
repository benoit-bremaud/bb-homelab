# AGENTS.md

> **Cross-agent rules**: the maintainer keeps a machine-local single source of truth at `~/.agent-rules/common.md` (Q&A pattern with MCDA decision matrix, pre-push and pre-merge gates, one chat per project, language rules, decision traceability). Agents running on the maintainer's machine **must read it first**. Precedence, stated once: rule/skill > `AGENTS.md` > `CLAUDE.md` > `~/.agent-rules/common.md` > `~/.claude/CLAUDE.md`, except that a global *safety* rule (secrets, force-push, destructive actions, merge approval) is never weakened by a project file. Documented project deviations are listed in `CLAUDE.md`. The repo stays self-contained for outside contributors: the essentials are restated below, never copied wholesale.

Shared instructions for any AI coding agent (or human contributor) working in this repository. This file is agent-agnostic by design: it depends on no specific tooling. If you are a new agent picking up this project, read this file first, then follow its links.

## 1. What this project is

`bb-homelab` is a self-hosted homelab running on a Raspberry Pi 5, designed to remain hardware-agnostic. It orchestrates containerised services (n8n today; Jellyfin, reverse proxy, monitoring planned) with a strong security and reproducibility posture.

- Repo visibility: **public** (since 2026-06-16). The Public Release Checklist in [CONTRIBUTING.md](CONTRIBUTING.md) was satisfied before the flip; treat every commit as world-readable — a leaked secret is public the instant it is pushed.
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
- Commit messages and code comments in **English**; docs follow the FR/EN split in `.claude/rules/docs-conventions.md`.

### Pre-push and pre-merge gates

- **Before every push** (no trivial-diff exception): a local read-only review of `origin/main...HEAD`, findings classified Must / Should / Nice / Disagree, every Must Have fixed. Claude Code: command `/review-local`.
- **Before every merge**, on the head SHA being merged, all green or no merge: (1) full checks — `shellcheck`, `markdownlint`, `yamllint`, `hadolint` (run in CI), plus `docker compose config` and `caddy validate` where touched (manual, not in CI); (2) coverage — N/A for pure infra/docs diffs, state it explicitly; doc coverage: every new service has a README; (3) local SonarQube gate (`sonar-scanner -Dsonar.qualitygate.wait=true`, project `bb-homelab`; the server is not reachable from CI); (4) `gitleaks` + manual diff read for secrets; (5) QA on the real artefact — see [docs/architecture/qa/](docs/architecture/qa/README.md).
- **Merge-approval question** (exact wording, only after CI, the local SonarQube gate and every open comment are verified): « J'ai contrôlé, et je te confirme que toute la CI est verte, SonarQube est lui aussi content, et tous les commentaires ouverts dans l'onglet conversation dans GitHub ont bel et bien eu une réponse inline, dans ce cas m'autorises-tu à merger cette PR ? »

### Chats and decisions

- One open chat per project, one task per chat, named `#N <issue title>`; the next chat opens only when the current task is fully finished (PRs merged, Must/Should done, Nice filed as issues, `PROJECT_LOG.md` and memory updated).
- Every choice between several solutions is preceded by an MCDA matrix (weights sum to 100, scores 0–5, totals /500) and asked with ranked clickable options, `(Recommandé)` on the top score only, plus a final « Approfondir l'analyse et expliquer » option.

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

Eight workflows live in [.github/workflows/](.github/workflows/). Actions are pinned by SHA.

Required on `main` (branch protection): `gitleaks`, `shellcheck`, `hadolint`, `markdownlint`, `yamllint`. Public-only (gated by visibility): `codeql`, `dependency-review`, `scorecard`.

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

- **Public repository (since 2026-06-16).** The Public Release Checklist in CONTRIBUTING.md (the source of truth) was satisfied before the flip. Every commit is now world-readable: a leaked secret is public immediately, so rotate-then-scrub is mandatory if one slips in.
- **No secrets in git.** `.env` and `.env.*` are gitignored. `.env.example` carries placeholders only. Credentials for n8n workflows live in the n8n UI, not in `.env`.
- **AI attribution: allowed, kept sober** (policy aligned on the global one, 2026-10-22). A `Co-Authored-By` trailer on commits and a "Generated with" footer on PR bodies are permitted. Docs, README, `PROJECT_LOG.md` and code comments carry no AI tool or brand names; reviewers appear as `automated review (X)`. Exceptions: see `.claude/rules/security-invariants.md`.
- Never force-push to `main` or `master`. Never commit `.env`, `*.pem`, `*.key`, `*.crt`.

## 8. Image and tooling pins

Service images are pinned in each `.env.example` (e.g. `N8N_IMAGE_TAG`, `CLOUDFLARED_IMAGE_TAG`). Bump deliberately via a dedicated PR — never silently.

## 9. PROJECT_LOG discipline

[PROJECT_LOG.md](PROJECT_LOG.md) is the operational journal, not a changelog. Every merged PR, architectural decision, or backlog change gets a dated entry. Convert relative dates to absolute (`Thursday` → `2026-04-23`) so entries stay interpretable later.

## 10. When you are unsure

- Read ARCHITECTURE.md + the relevant layer's `README.md`.
- Search [docs/decisions/](docs/decisions/) for a matching ADR.
- If still unclear, open an issue or ask the human — do not guess.
