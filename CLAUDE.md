# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Read this first

The authoritative, agent-agnostic brief lives in [AGENTS.md](AGENTS.md). Read it before doing anything. It covers:

- Project purpose (self-hosted Raspberry Pi homelab) and the 6-layer DIP architecture.
- The document hierarchy: [README.md](README.md), [ARCHITECTURE.md](ARCHITECTURE.md), [CONTRIBUTING.md](CONTRIBUTING.md) (source of truth for workflow), [PROJECT_LOG.md](PROJECT_LOG.md), [docs/decisions/](docs/decisions/).
- Branching, Conventional Commits, PR review procedure, merge gate.
- CI checks (5 required on `main`: gitleaks, shellcheck, hadolint, markdownlint, yamllint).
- Common commands (n8n compose, backup, bootstrap, Tailscale).
- Security invariants (private-first repo, no secrets, no AI attribution in tracked files).

## Claude Code specifics

### Harness permissions

Pre-authorised commands for this repo are listed in the local Claude Code config file `.claude/settings.json` (gitignored — see `.gitignore`). It also grants access to the additional directory `services/n8n`. Extend that file (not ad-hoc prompts) when new repeating commands need to run without prompting.

### Interaction conventions

- Respond in English in code, commits, PRs, and docs. Human conversation may be in French; tracked artefacts stay in English.
- When asking the human a question, use the `AskUserQuestion` tool with ranked, clickable choices — never open-ended prose questions.
- Plan before coding non-trivial changes. Present the plan, wait for approval, then implement.
- Never merge a PR without the full gate described in AGENTS.md §4 and CONTRIBUTING.md.

### No AI attribution

Do not add `Co-Authored-By` AI lines, "Generated with …" footers, or any mention of Claude / Copilot / GPT in commits, PR bodies, comments, or tracked files. This is strict.

### Tooling pins and agent-agnostic docs

If you update AGENTS.md, CONTRIBUTING.md, or PROJECT_LOG.md, keep them tool-neutral — no references to a specific agent. Claude-specific content stays in this file.

## Quick sanity checklist before pushing

1. `shellcheck` / `markdownlint-cli2` / `yamllint` pass locally.
2. No `.env`, `*.pem`, `*.key`, `*.crt` staged.
3. Commit subject follows Conventional Commits.
4. Branch is `<type>/<issue-number>-<slug>`, not `main`.
5. PROJECT_LOG.md entry added if merging a PR.
