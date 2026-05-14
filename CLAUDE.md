# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when
working in this repository. It is intentionally short: a navigation
index pointing to the authoritative briefs.

## Authoritative documents (read in order)

1. [AGENTS.md](AGENTS.md) — **agent-agnostic onboarding brief** (project
   purpose, 6-layer DIP architecture, document hierarchy, workflow rules,
   CI checks, common commands, security invariants). Read this first.
2. [`.claude/rules/`](.claude/rules/) — **modular Claude-specific rules**:
   - [docs-rules.md](.claude/rules/docs-rules.md) — language conventions
     (FR/EN by category), markdownlint config, ADR pattern, PROJECT_LOG
     discipline.
   - [infra-rules.md](.claude/rules/infra-rules.md) — shell scripts,
     Docker compose patterns, fstab UUID + nofail, systemd, SSH to Pi.
   - [workflow-pr-rules.md](.claude/rules/workflow-pr-rules.md) —
     branch naming, Conventional Commits, merge gate, Q&A before
     decisions, step-by-step execution, post-merge cleanup.
   - [security-rules.md](.claude/rules/security-rules.md) — AI
     attribution policy (strict), secrets handling, private-first repo,
     risky actions, token rotation procedure.

When this file, AGENTS.md, and a rule disagree, the order of
precedence is: specific rule > AGENTS.md > this file > global
`~/.claude/CLAUDE.md`.

## Claude Code specifics

### Harness permissions

Pre-authorised commands for this repo are listed in the local Claude
Code config file `.claude/settings.json` (gitignored — see
`.gitignore`). It also grants access to the additional directories
`services/n8n/` and `services/caddy/`. Extend that file (not ad-hoc
prompts) when new repeating commands need to run without prompting.

Personal overrides go in `.claude/settings.local.json` (also
gitignored). The pattern lets one machine differ from another (e.g.
testing a new permission locally without committing it).

### Interaction conventions

- Respond in English in code, commits, PRs, and tracked Category B/C
  docs. Human conversation may be in French; Category A docs (READMEs,
  ARCHITECTURE.md, ADRs, bootstrap/network/services/storage/*.md) are
  in French.
- When asking the human a question, use the `AskUserQuestion` tool
  with ranked, clickable choices — never open-ended prose questions.
- Plan before coding non-trivial changes. Present the plan, wait for
  approval, then implement.
- **Never merge a PR without the full merge gate** described in
  [workflow-pr-rules.md](.claude/rules/workflow-pr-rules.md) §Merge
  gate.

### Skills, subagents, commands

Custom workflows live in:

- `.claude/skills/<name>/SKILL.md` — invokable via Skill tool
- `.claude/agents/<name>.md` — specialised subagents
- `.claude/commands/<name>.md` — slash commands

These are populated as the project grows; see the corresponding issue
for the modularisation effort (#82).

## Quick sanity checklist before pushing

1. `shellcheck` / `markdownlint-cli2` / `yamllint` pass locally.
2. No `.env`, `*.pem`, `*.key`, `*.crt` staged.
3. Commit subject follows Conventional Commits.
4. Branch is `<type>/<issue-number>-<slug>`, not `main`.
5. PROJECT_LOG.md entry added if merging a PR.
