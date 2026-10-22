# Security invariants — bb-homelab

Project-specific security invariants. This rule is loaded at every
session start (no `paths:` frontmatter) because security applies
everywhere, not just to specific file types. It extends the
agent-agnostic brief in [AGENTS.md](../../AGENTS.md) §7 and the
global rules in `~/.claude/CLAUDE.md`.

## AI attribution — allowed, kept sober

Policy aligned on the global one on 2026-10-22 (it was STRICT before;
the global policy was reversed on 2026-07-02 — transparency over
concealment). Attribution is permitted, never mandatory, and never
replaces real authorship of decisions.

Allowed:

- A `Co-Authored-By` AI trailer on commits (the standard harness
  trailer)
- A "Generated with …" footer on PR bodies

The trailer belongs to commits and the footer to PR descriptions only:
PR comments and commit bodies name no tool beyond them.

Kept out of the documentation, so the audit trail stays about the
infrastructure and not the tooling:

- `README.md`, `CONTRIBUTING.md`, `ARCHITECTURE.md`, ADRs, service
  docs, code comments and `PROJECT_LOG.md` carry no AI tool or brand
  names (`Claude`, `Copilot`, `GPT`, `Codex`…)

Exceptions to that last rule:

- This file and `CLAUDE.md` / `.claude/rules/` / `.claude/skills/`
  (Category B — agent instructions, where naming tools is necessary
  by purpose: workflow skills reference literal GitHub API field
  values such as `user.login == "Copilot"` for review automation)
- Factual narrative in PROJECT_LOG about historical incidents (e.g.
  "Copilot reviewer was set as required in PR #53") — these are
  history references, not authorship attributions
- Filenames like `.codex` (literal artefact name, can't be renamed)

For PROJECT_LOG reviewer attributions, **always** use
`automated review (X)` form. See
[docs-conventions](docs-conventions.md) §PROJECT_LOG discipline.

## Secrets — never in git

- `.env` and `.env.*` are gitignored.
- `.env.example` carries placeholder values only.
- n8n workflow credentials live in the n8n UI; **never** in `.env`.
- Cert / key patterns are gitignored: `*.pem`, `*.key`, `*.crt`
  (defensive, added in PR #60).
- `N8N_ENCRYPTION_KEY` lives in two places:
  1. `services/n8n/.env` on the Pi (loaded at runtime).
  2. The user's password manager (canonical source of truth).
  Losing it = losing every credential n8n holds.

## Public repository (since 2026-06-16)

`bb-homelab` is **public**. The security subset of the Public Release
Checklist below was satisfied before the flip (see PROJECT_LOG
2026-06-16; `gitleaks` on full history returned 0 leaks). The canonical
checklist lives in [CONTRIBUTING.md](../../CONTRIBUTING.md) (it adds a
SonarQube Quality-Gate item); this list stays here as the satisfied
security record and the bar any future history rewrite must clear — and
because the consequence is now permanent: every commit is world-readable
the instant it is pushed, so a leaked secret is public immediately
(rotate first, then scrub).

1. `gitleaks detect --source . --verbose` passes on full git history ✅
2. No secrets in any tracked file (anything ever committed is
   forever in history — secrets must have been rotated) ✅
3. `.env.example` files have placeholder values only ✅
4. All development secrets rotated (bot tokens, OAuth credentials,
   API keys) ✅ (none were ever committed)
5. CI includes secret detection job (gitleaks workflow since PR #33) ✅

## Branch protection

The `main` branch is protected:

- CI-gated merge (5 required checks)
- `enforce_admins: true` (admins included in the rule)
- Force-push forbidden
- Branch deletion forbidden via the UI

Tag rule scoped to `refs/tags/v*`:

- Creation / update / deletion blocked
- Bypass only for `RepositoryRole: Admin` (owner emergency exit)

## Risky actions — always confirm

The agent must request user confirmation before any of these:

- Deleting files / branches (local or remote)
- Force-pushing (any branch — never main without explicit user ask)
- Creating or merging PRs (the merge gate covers this)
- Modifying CI/CD pipelines (`.github/workflows/`)
- Destructive git operations (`git reset --hard`, `git checkout --`,
  `git clean -f`, `git filter-repo`)
- Touching Pi shared state (services restart, fstab edits, disk wipes,
  partition operations)
- Anything visible to others (Slack messages, GitHub comments on
  third-party repos, etc.)

A user approval for one action does NOT extend to "all similar
actions in the future" — confirm each occurrence unless the user has
explicitly delegated a class of operations (e.g. "all PR replies
during this session").

## Token rotation procedure

If a credential leaks (screenshot exposed, paste error, etc.):

1. **Revoke** the leaked token immediately on the issuing platform
2. **Generate** a new one
3. **Update** the `.env` on the Pi (or wherever it lives)
4. **Restart** affected services (`docker compose restart <service>`)
5. **Log the incident** in `PROJECT_LOG.md` as a "Token rotation
   incident" entry (cf. PR #62 entry for the SonarCloud token
   incident from 2026-04-26)

The lesson is captured: never paste secrets directly in chat; never
screenshot a page that displays a secret value, even if you intend to
hide it after.
