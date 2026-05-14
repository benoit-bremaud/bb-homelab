---
name: pr-cycle
description: Full PR workflow for bb-homelab — from a GitHub issue to merge readiness. Handles branch creation, conventional commit, push, gh pr create with template, metadata application (assignee/labels/project board/Copilot reviewer), CI + auto-review monitoring, comment classification + inline reply, merge-readiness summary, and post-merge cleanup. Invoke with /pr-cycle <issue-number> when starting a chantier that will land as a PR.
disable-model-invocation: true
---

# /pr-cycle <issue-number> — full PR workflow

Run this skill to execute the complete PR cycle for bb-homelab. The
`<issue-number>` is the GitHub issue this PR will close.

## Prerequisites (verify before invocation)

- On `main` with clean working tree (`git status` must be empty)
- Issue `<issue-number>` exists with labels + assignee + project board
- The chantier scope has been Q&A'd with the user (what files, what
  approach, what done criteria)

## Phase A — Branch + first commit (~5 min)

1. **Determine branch name** per the `pr-workflow` skill:

   ```text
   <type>/<issue-number>-<slug>
   ```

   Types: `feat`, `fix`, `chore`, `docs`, `ci`, `security`, `infra`.

2. **Create the branch**:

   ```bash
   git checkout -b <type>/<issue-number>-<slug>
   ```

3. **Implement** — driven by user step-by-step (per the `pr-workflow`
   skill §Step-by-step execution). After every 2-4 files, pause for
   a relecture checkpoint (per the `pr-workflow` skill §Regular relecture).

4. **Stage + commit** with Conventional Commits format:

   ```bash
   git add <files>
   git commit -m "<type>(<scope>): <short>

   <body>

   Closes #<issue-number>"
   ```

## Phase B — Push + PR creation (~3 min)

1. **Push**:

   ```bash
   git push -u origin <branch>
   ```

2. **Open the PR** with structured template:

   ```bash
   gh pr create --title "..." --body "$(cat <<'EOF'
   ## Summary
   ...
   ## Changes
   ...
   ## Audit performed
   ...
   ## Out of scope
   ...
   Closes #<issue-number>
   EOF
   )"
   ```

3. **Apply metadata** (use the recipe from
   `~/.claude/skills/pr-create/SKILL.md` — the global skill covers
   the assignee/labels/project board/Copilot reviewer API calls).

   For bb-homelab specifically, project board ID is
   `PVT_kwDOB_c7A84BLhxu`.

## Phase C — Monitor CI + review (background)

1. **Launch background monitor** — wait until all checks have
   completed (no longer IN_PROGRESS / QUEUED / PENDING) AND at least
   one auto-reviewer has posted:

   ```bash
   until [ "$(gh pr view <n> --json statusCheckRollup --jq '[.statusCheckRollup[] | select(.status == "IN_PROGRESS" or .status == "QUEUED" or .status == "PENDING")] | length')" = "0" ] \
     && [ "$(gh api repos/benoit-bremaud/bb-homelab/pulls/<n>/reviews --jq '[.[] | select(.user.login == "Copilot" or .user.login == "copilot-pull-request-reviewer[bot]" or .user.login == "chatgpt-codex-connector[bot]")] | length')" -gt "0" ]; do
     sleep 30
   done
   ```

2. **Mandatory failure check** after the monitor exits — the loop
   above only waits for completion, not success. A FAILED, CANCELLED,
   or TIMED_OUT check still counts as "completed" and would exit the
   loop. Always run this gate before proceeding to Phase D:

   ```bash
   FAILED=$(gh pr view <n> --json statusCheckRollup \
     --jq '[.statusCheckRollup[] | select(.conclusion == "FAILURE" or .conclusion == "CANCELLED" or .conclusion == "TIMED_OUT")] | length')
   if [ "$FAILED" -gt "0" ]; then
     echo "❌ CI not green ($FAILED check(s) failed). Investigate before any merge action."
     gh pr view <n> --json statusCheckRollup --jq '.statusCheckRollup[] | select(.conclusion == "FAILURE" or .conclusion == "CANCELLED" or .conclusion == "TIMED_OUT") | {name, conclusion}'
     # STOP here — do not proceed to Phase D/E. Surface to user, await
     # diagnostic and fix (push to retrigger or root-cause first).
   fi
   ```

3. If Copilot doesn't post automatically (422 on `requested_reviewers`
   because not a collaborator), prompt the user to add Copilot
   manually via the GitHub UI.

## Phase D — Review handling (per `~/.claude/skills/pr-review-procedure`)

1. **Fetch all inline comments**:

   ```bash
   gh api repos/benoit-bremaud/bb-homelab/pulls/<n>/comments
   ```

2. **Classify each comment**:
    - **Must Have** — logic bug, security, data loss → implement fix
    - **Should Have** — code quality, naming → implement if low effort
    - **Nice to Have** — style preference → ack/defer
    - **Disagree** — explain why with technical justification

3. **Reply inline** to each comment (never in a block):

    ```bash
    gh api repos/benoit-bremaud/bb-homelab/pulls/<n>/comments/<comment-id>/replies \
      -X POST --input - <<'EOF'
    {"body": "**<priority> — applied in <commit-sha>.**\n\n<explanation>"}
    EOF
    ```

4. **After every push**, re-fetch comments — auto-reviewers may
    post additional rounds (typically up to 2-3 cycles).

## Phase E — Merge readiness + user approval

1. **Verify all gate conditions** (per the `pr-workflow` skill §Merge gate):
    - All required CI checks green
    - Auto-reviewer posted (requested ≠ posted)
    - Every comment addressed
    - mergeStateStatus = `CLEAN`

2. **Present merge-readiness summary** to user, e.g.:
    > "CI green (5/5 required + Sonar). Copilot posted X comments — all
    > addressed in `<sha>`. mergeStateStatus CLEAN. Ready to merge PR #<n>?"

3. **WAIT for user's explicit textual approval**: "ok", "ok merge",
    "merge it", "go ahead". Without this, do not proceed.

## Phase F — Merge + cleanup

1. **Squash merge with branch deletion**:

    ```bash
    gh pr merge <n> --squash --delete-branch
    ```

    **NEVER** use `--auto`, `--admin`, or any bypass flag.

2. **Post-merge cleanup**:

    ```bash
    git checkout main
    git pull origin main
    git branch -d <branch>
    git remote prune origin
    git status  # must be clean
    git log --oneline -3  # confirm merge SHA on main
    ```

## Phase G — PROJECT_LOG entry (mini-PR follow-up)

> **Termination rule (critical, prevents infinite recursion):** Phase
> G is **skipped entirely** when the PR being cycled is itself a
> `docs/project-log-pr*` PR (i.e. the mini-PR that adds the
> PROJECT_LOG entry). Check the branch name before entering this
> phase — if it starts with `docs/project-log-pr`, the cycle ends
> at Phase F's post-merge cleanup. A PROJECT_LOG entry mini-PR does
> not get its own PROJECT_LOG entry.

1. **Skip Phase G if the branch is already a PROJECT_LOG mini-PR**:

    ```bash
    if [[ "$(git rev-parse --abbrev-ref HEAD)" == docs/project-log-pr* ]]; then
      echo "PROJECT_LOG mini-PR detected — Phase G skipped (termination rule)."
      # End of /pr-cycle.
    fi
    ```

    (After Phase F you're already on `main`, so check the branch you
    were on BEFORE merge — or pass it as a variable through Phase F.)

2. **Otherwise — create the mini-PR for the PROJECT_LOG entry**:

    ```bash
    git checkout -b docs/project-log-pr<n>
    ```

    Append a dated entry to `PROJECT_LOG.md` referencing the merge
    SHA + summary + review trouvailles (use `automated review (X)`
    form per `docs-conventions` rule).

3. **Open and merge the mini-PR** using this same `/pr-cycle` skill
    recursively. The termination rule above guarantees this call
    will skip its own Phase G — exactly one PROJECT_LOG entry per
    feature PR, never more.

## Failure recovery

- **CI billing failure**: tell user to check
  https://github.com/settings/billing/spending_limit before retry.
- **mergeStateStatus UNKNOWN**: GitHub recomputes after push; wait
  60s, re-query. Don't proceed until CLEAN.
- **Copilot can't be added (422)**: user adds manually via UI.
- **Reviewer flagged Must Have**: never merge until addressed.

## Related skills

- `~/.claude/skills/pr-create/SKILL.md` — generic PR-creation recipe
  (assignee/labels/project/Copilot)
- `~/.claude/skills/pr-review-procedure/SKILL.md` — inline reply
  procedure
- `~/.claude/skills/vsea-merge-gate/SKILL.md` — equivalent for V-SEA
  repo (different project board, otherwise same gate)
- `pr-workflow` skill (this repo) — the canonical PR workflow rules
  this skill operationalises
