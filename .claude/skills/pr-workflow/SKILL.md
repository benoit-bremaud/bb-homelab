---
name: pr-workflow
description: PR workflow rules for bb-homelab. Branch naming (`<type>/<issue>-<slug>`), Conventional Commits, the strict 6-step merge gate (CI green + auto-reviewer posted + comments addressed + summary + explicit user approval + then merge), Q&A before each decision via AskUserQuestion, step-by-step execution, regular relecture checkpoints on multi-file work, post-merge cleanup sequence, PROJECT_LOG entry discipline. One chat per project / one task per chat, pre-push and pre-merge gates, MCDA matrix before every choice. Apply when working with git branches, opening PRs, addressing review comments, or merging.
---

# PR workflow — bb-homelab

Project-specific rules for branches, commits, pull requests, and the
merge gate. This skill extends the agent-agnostic brief in
[AGENTS.md](../../../AGENTS.md) §4 and the global rules in
`~/.claude/CLAUDE.md`.

## Branch naming

Pattern: `<type>/<issue-number>-<slug>`

Supported `<type>` values:

- `feat`, `fix`, `chore`, `docs`, `ci`, `security`, `infra`

Examples:

- `feat/14-caddy-reverse-proxy`
- `docs/77-fr-readme`
- `chore/69-version-agent-md`

Never commit directly to `main` — branch protection forbids it
(cf. [security-invariants](../../rules/security-invariants.md)).

## Conventional Commits

Format: `<type>(<scope>): <short description>`

Body and footer follow standard Conventional Commits syntax.
Closing keyword on the last line: `Closes #N` (auto-closes the issue
on merge).

Examples:

- `feat(services/caddy): deploy reverse proxy with internal CA + ADR 0002`
- `docs(project-log): record PR #79 merge`
- `chore(repo): version AGENTS.md + CLAUDE.md, gitignore .codex`
- `infra(claude): modularise rules + version .claude/rules`

Commit messages are in English by convention (cf.
[docs-conventions](../../rules/docs-conventions.md) Category C).

## Chats — one project, one task

Rule source: `~/.agent-rules/common.md` § One chat per project, one task
per chat.

- Never more than one open chat on this repository (worktrees
  included): check `list_sessions` before starting or forking one.
- One task per chat, named `#N <issue title>` after the issue it works
  on. Reuse the existing issue, or create one (labels, project board
  `bb-homelab` #48, status `Todo`); the PR closes it (`Closes #N`).
- Open the next chat only when the task is fully finished: PRs merged
  after the gates, Must/Should done, Nice filed as issues,
  `PROJECT_LOG.md` and memory updated.

## Pre-push gate — every push, no trivial-diff exception

Before every `git push`, run the global `/review-local` command (or a
structured read-only review of `origin/main...HEAD`). Classify each
finding Must / Should / Nice / Disagree with `file:line`, answer every
one, and push only when every Must Have is fixed and the local linters
pass (see [AGENTS.md](../../../AGENTS.md) §5). If a reviewer tool could
not run, say so explicitly.

## Pre-merge gate — five steps, on the head SHA, all green

Any new commit re-runs it. Record numbers and evidence in the review
report. The only exception is a final evidence-only commit: if it touches
nothing outside `docs/architecture/qa/**` and
`docs/architecture/review-local.md`, it does not re-run the gate (any other
file in it does).

1. **Checks, full not partial**: `shellcheck`, `markdownlint-cli2`,
   `yamllint`, `hadolint` (run in CI), plus `docker compose config`
   and `caddy validate` for touched services (manual, not in CI).
2. **Coverage**: tests N/A for pure infra/docs diffs (state it); doc
   coverage: every new or changed service has an up-to-date README.
3. **SonarCloud gate** passed on that SHA.
4. **Secrets**: `gitleaks` (full history, the repo is public), no
   tracked `.env` or `.env.*` except the `.env.example` templates
   (`git ls-files '.env*' '**/.env*' | grep -v '\.env\.example$'` must
   print nothing), manual read of the diff for keys, tokens, IDs.
5. **QA on the real artefact**: see
   [docs/architecture/qa/README.md](../../../docs/architecture/qa/README.md).

## Merge gate — strict, non-negotiable

Every merge on `main` requires all of the following, in order:

1. ✅ **All required CI checks green** (5 currently: `Detect secrets`,
   `Lint shell scripts`, `Lint Dockerfiles`, `Lint Markdown`,
   `Lint YAML`). SonarCloud Cloud scan is also checked but not yet
   required (cf. issue #65).
2. ✅ **Automated reviewer posted its review** — requested ≠ posted.
   Wait until Copilot or codex has actually submitted a review on the
   final commit before continuing.
3. ✅ **Every review comment addressed inline** (skill
   `pr-review-procedure`: verify each claim against the code, one issue
   per question to the owner, never resolve conversations) with
   classification:
   - **Must Have** — logic bug, security, data loss → implement fix
   - **Should Have** — code quality, naming, readability → implement
     if low effort
   - **Nice to Have** — style preference, optimisation → ack/defer
   - **Disagree** — explain why with technical justification
4. ✅ **Merge-approval question** asked verbatim, once CI,
   SonarCloud and every open Conversation comment are verified (if one
   of the three fails, say which and do not ask):
   > « J'ai contrôlé, et je te confirme que toute la CI est verte,
   > SonarQube est lui aussi content, et tous les commentaires ouverts
   > dans l'onglet conversation dans GitHub ont bel et bien eu une
   > réponse inline, dans ce cas m'autorises-tu à merger cette PR ? »
5. ✅ **User replies with explicit approval** ("ok", "ok merge",
   "merge it", "go ahead", etc.).
6. ✅ **Only then**: `gh pr merge --squash --delete-branch`.

**Never use `--auto`, `--admin`, or any bypass flag** without explicit
user request for that specific operation. Skipping any step is
forbidden, even when CI is green and "nothing seems wrong".

## Q&A before each decision

Before any decision (technical, organisational, naming, scope):

1. Stop — do not propose a single recommended path and execute.
2. Study first, then show the MCDA matrix (skill `mcda-decision`:
   options A/B/C, weights summing to 100, scores 0–5 with a one-line
   justification, totals /500, sensitivity check). Open Q&A with
   `AskUserQuestion`: ranked options, each showing its score,
   `(Recommandé)` on the top score only, and a final
   « Approfondir l'analyse et expliquer » option.
3. Wait for user's choice before any action.
4. After choice: execute that one step, report, then re-open Q&A for
   the next decision.

This extends the durable feedback memory
`~/.claude/projects/.../memory/feedback_qa_before_decisions.md`.

Edge case: trivial actions inside an already-validated step (e.g.
`git status` to verify a previous action) do not need Q&A.

## Step-by-step execution

Multi-step plans: execute **one step at a time**, validate, wait for
"ok" before next step. Never batch.

Cf. `~/.claude/projects/.../memory/feedback_step_by_step.md`.

## Regular relecture checkpoints

On multi-file chantiers (≥3 related files), pause every 2-4 files for
a coherence audit:

- No drift across files (naming, version pins, paths)
- No bloat or speculative content
- No contradictions
- No AI tool names leaked into docs (per security-invariants.md)

Cf. `~/.claude/projects/.../memory/feedback_regular_relecture.md`.

## Post-merge cleanup (standard sequence)

```bash
git checkout main
git pull origin main
git branch -d <branch>
git remote prune origin
git status  # must be clean
git log --oneline -3  # confirm merge SHA on main
```

Then run the recency-graded memory compression pass: the newest brick
keeps its full detail in the project memory, older entries shrink to
one line (done + SHA + gist) or move to `archive/`. Keep standing
reference, compress action narratives.

## PROJECT_LOG entry

Every merged PR gets a real-time dated entry in `PROJECT_LOG.md`. See
[docs-conventions](../../rules/docs-conventions.md) §PROJECT_LOG discipline for format and
reviewer attribution convention.

The PROJECT_LOG entry is typically a separate mini-PR opened
immediately after merge (because the squash merge SHA does not exist
until merge completes).
