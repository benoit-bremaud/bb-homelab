# PR workflow rules — bb-homelab

Project-specific rules for branches, commits, pull requests, and the
merge gate. These extend the agent-agnostic brief in
[AGENTS.md](../../AGENTS.md) §4 and the global rules in
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
(cf. [security-rules.md](security-rules.md)).

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
[docs-rules.md](docs-rules.md) Category C).

## Merge gate — strict, non-negotiable

Every merge on `main` requires all of the following, in order:

1. ✅ **All required CI checks green** (5 currently: `Detect secrets`,
   `Lint shell scripts`, `Lint Dockerfiles`, `Lint Markdown`,
   `Lint YAML`). SonarCloud Cloud scan is also checked but not yet
   required (cf. issue #65).
2. ✅ **Automated reviewer posted its review** — requested ≠ posted.
   Wait until Copilot or codex has actually submitted a review on the
   final commit before continuing.
3. ✅ **Every review comment addressed inline** with classification:
   - **Must Have** — logic bug, security, data loss → implement fix
   - **Should Have** — code quality, naming, readability → implement
     if low effort
   - **Nice to Have** — style preference, optimisation → ack/defer
   - **Disagree** — explain why with technical justification
4. ✅ **Merge-readiness summary** presented to the user:
   > "CI green, automated review posted with X comments — all
   > addressed. Ready to merge PR #N?"
5. ✅ **User replies with explicit approval** ("ok", "ok merge",
   "merge it", "go ahead", etc.).
6. ✅ **Only then**: `gh pr merge --squash --delete-branch`.

**Never use `--auto`, `--admin`, or any bypass flag** without explicit
user request for that specific operation. Skipping any step is
forbidden, even when CI is green and "nothing seems wrong".

## Q&A before each decision

Before any decision (technical, organisational, naming, scope):

1. Stop — do not propose a single recommended path and execute.
2. Open Q&A with `AskUserQuestion`, ranked options + descriptions
   accessible to a non-expert.
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
- No AI references leaked (per security-rules.md)

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

## PROJECT_LOG entry

Every merged PR gets a real-time dated entry in `PROJECT_LOG.md`. See
[docs-rules.md](docs-rules.md) §PROJECT_LOG discipline for format and
reviewer attribution convention.

The PROJECT_LOG entry is typically a separate mini-PR opened
immediately after merge (because the squash merge SHA does not exist
until merge completes).
