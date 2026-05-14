---
name: audit-status
description: Quick snapshot of bb-homelab state — current branch, working tree, last commits on main, open PRs, hardware blockers (#47 enclosures), local branches, dette résiduelle. Invoke at session start or whenever the answer to "où en sommes-nous ?" is unclear. Read-only, no side effects.
disable-model-invocation: true
---

# /audit-status — bb-homelab snapshot

Run this skill to get a structured snapshot of the bb-homelab
project state. Useful at session start, after a long pause, or when
context becomes unclear.

## Procedure

Execute these commands and present the output as a structured
Markdown report.

### 1. Local git state

```bash
echo "=== branch + working tree ==="
git branch --show-current && git status --short
```

Expected: on `main` with empty status (working tree clean). Anything
else is the first signal to discuss with the user.

### 2. Last commits on main

```bash
echo "=== last 5 commits on main ==="
git log main --oneline -5
```

Validates: where main currently points, recent merges traceable.

### 3. Open pull requests

```bash
echo "=== open PRs ==="
gh pr list --state open --json number,title,headRefName,createdAt \
  --jq '[.[] | {n: .number, title, branch: .headRefName, created: .createdAt}]'
```

For each open PR, also fetch:

```bash
gh pr view <n> --json mergeStateStatus,statusCheckRollup,reviews
```

So Claude can summarise: PRs awaiting review, PRs blocked, PRs ready
to merge but waiting for user explicit approval.

### 4. Hardware / external blockers

```bash
echo "=== hardware blockers ==="
gh issue view 47 --json state,title
```

Issue #47 (USB-SATA enclosures) is the main hardware blocker that
gates several MVP CORE done criteria. Surface its state explicitly.

### 5. Local branches (orphans?)

```bash
git branch -a | head -20
```

If branches other than `main` exist locally, list them — they may be
forgotten chantiers awaiting cleanup or resumption.

### 6. Dette résiduelle

From the previous session's PROJECT_LOG entries (the last
`## YYYY-MM-DD` section in `PROJECT_LOG.md`), identify any "pending"
notes:

```bash
tail -60 PROJECT_LOG.md
```

Common patterns to flag:

- `Cron: not yet activated`
- `Pending (post-merge, manual on Pi)`
- `Out of scope: ...`

## Output format

Present a single Markdown report with these sections:

```markdown
## 📊 Snapshot bb-homelab (YYYY-MM-DD HH:MM UTC)

### 🌿 Git state
- Branch: `main` (or other)
- Working tree: clean (or list dirty files)
- Last 3 commits: ...

### 📦 Open PRs
- #N <title> — branch / state / CI / reviews count
(or "0 open PRs" if clean)

### 🚧 Blockers
- #47 USB-SATA enclosures: <state> — gates: <list of dependent done criteria>

### 🧹 Local branches awaiting cleanup
- (list or "main only")

### ⏳ Dette résiduelle identified
- (from PROJECT_LOG pending notes)

### 🎯 Suggested next step
- (Claude's best guess based on the state above)
```

## When NOT to invoke

- During an ongoing multi-step task — Claude already has the context
- For investigating a specific bug or file — use Read / Grep directly
- For backlog deep dive — use `gh issue list` + manual review

This skill is for **orientation snapshots**, not deep investigation.

## Related

- `pr-workflow` skill — for PR-related operations
- `restore-test-n8n` skill — if a backup test is among pending items
- `~/.claude/skills/project-log-discipline/SKILL.md` — PROJECT_LOG conventions
