# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when
working in this repository. It is intentionally short: a navigation
index pointing to the authoritative briefs.

## Authoritative documents (read in order)

1. [AGENTS.md](AGENTS.md) — **agent-agnostic onboarding brief** (project
   purpose, 6-layer DIP architecture, document hierarchy, workflow rules,
   CI checks, common commands, security invariants). Read this first.
2. [`.claude/rules/`](.claude/rules/) — **path-scoped or session-start
   rules** (loaded conditionally or at session start, per Claude Code
   conventions):
   - [`docs-conventions.md`](.claude/rules/docs-conventions.md) — loads
     when Claude reads any `**/*.md` file. Language conventions (FR/EN
     by category), markdownlint config + known false positives, ADR
     pattern, PROJECT_LOG discipline.
   - [`security-invariants.md`](.claude/rules/security-invariants.md) —
     loads at session start (no `paths:`, always relevant). AI
     attribution policy (strict), secrets handling, repo
     visibility (public), branch protection, risky actions, token
     rotation.
3. [`.claude/skills/`](.claude/skills/) — **behaviour-scoped skills**
   (loaded by Claude when the description matches the task, or invoked
   via `/skill-name`):
   - [`infra-patterns`](.claude/skills/infra-patterns/SKILL.md) —
     shell scripts, Docker compose patterns, fstab UUID + nofail,
     systemd, SSH to Pi.
   - [`pr-workflow`](.claude/skills/pr-workflow/SKILL.md) — branch
     naming, Conventional Commits, merge gate, Q&A before decisions,
     step-by-step execution, post-merge cleanup.

When this file, AGENTS.md, and a rule/skill disagree, the order of
precedence is: specific rule/skill > AGENTS.md > this file > global
`~/.claude/CLAUDE.md`.

## Why rules vs skills (the split)

Both are official Claude Code conventions; we use both:

- **Rules** (`.claude/rules/<name>.md`) are good for guidance that
  should load based on file paths (e.g. all `*.md` → docs conventions)
  or that must always be in context (e.g. security policy at every
  session start). Rules are pure guidance Claude reads.
- **Skills** (`.claude/skills/<name>/SKILL.md`) are good for behavioural
  patterns Claude judges relevant from a description, or for
  workflows you can invoke with `/skill-name`. Skills can also bundle
  scripts and templates next to the prompt.

Our split:

| Topic | Mechanism | Reason |
|---|---|---|
| docs-conventions | rule with `paths: ['**/*.md']` | Path-scoped to markdown files |
| security-invariants | rule without `paths:` | Always loaded at session start |
| infra-patterns | skill | Behaviour scope (shell + docker + Pi ops) hard to express as a single glob |
| pr-workflow | skill | Behavioural (PR cycle, merge gate), not file-scoped |

## Claude Code specifics

### Harness permissions

Pre-authorised commands for this repo live in `.claude/settings.json`
(gitignored — see `.gitignore`). Personal overrides go in
`.claude/settings.local.json` (also gitignored). Extend those files
(not ad-hoc prompts) when new repeating commands need to run without
prompting.

### Interaction conventions

- Respond in English in code, commits, PRs, and tracked Category B/C
  docs. Human conversation may be in French; Category A docs (READMEs,
  ARCHITECTURE.md, ADRs, bootstrap/network/services/storage/*.md) are
  in French.
- When asking the human a question, use the `AskUserQuestion` tool
  with ranked, clickable choices — never open-ended prose questions.
- Plan before coding non-trivial changes. Present the plan, wait for
  approval, then implement.
- **Never merge a PR without the full merge gate** described in the
  `pr-workflow` skill.

### Future skills / agents / hooks

- `.claude/skills/<name>/SKILL.md` — for workflow skills (Phase 3 to
  come: `audit-status`, `pr-cycle`, `restore-test-n8n`, `new-service`).
- `.claude/agents/<name>.md` — subagents (Phase 4: `homelab-auditor`,
  `docs-writer-fr`, `pr-reviewer`).
- Hooks live inside `.claude/settings.json` under the `hooks` key
  (Phase 5 — auto-format markdown, reminders after merges, etc.).

## Quick sanity checklist before pushing

1. `shellcheck` / `markdownlint-cli2` / `yamllint` pass locally.
2. No `.env`, `*.pem`, `*.key`, `*.crt` staged.
3. Commit subject follows Conventional Commits.
4. Branch is `<type>/<issue-number>-<slug>`, not `main`.
5. PROJECT_LOG.md entry added if merging a PR.
