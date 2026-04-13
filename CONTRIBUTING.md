# Contributing

This is a personal homelab repo, but it follows the same conventions as
the public `impropedia` project so muscle memory transfers.

## Workflow

1. Pick (or open) an issue. Discuss approach if not obvious.
2. Branch from `main`: `<type>/<issue-number>-<slug>`
   (e.g. `feat/12-deploy-jellyfin`, `chore/3-bootstrap-script`).
3. Commit with [Conventional Commits](https://www.conventionalcommits.org/):
   `<type>(<scope>): <short description>`
4. Open a PR. Body includes:
   - **Summary** (what / why)
   - **Checklist** (build, lint, security, docs)
   - `Closes #<issue>` (so the issue auto-closes on merge)
5. Wait for CI green + review (Copilot or human).
6. Squash-merge unless there is a strong reason to keep individual commits.

## PR review comments

Mandatory procedure (mirrors the global rule from `~/.claude/CLAUDE.md`):

- Every comment gets an inline reply (never a single block summary).
- Classify by priority: Must Have / Should Have / Nice to Have / Disagree.
- Implement Must/Should fixes; explain Disagree with technical reasoning.
- Do not resolve conversations programmatically — that's a human action.

## Security

- `.env` and `.env.local` are gitignored. **Never** commit secrets, tokens,
  passwords, chat IDs, or instance IDs.
- All credentials live either in n8n encrypted credentials (protected by
  `N8N_ENCRYPTION_KEY`) or in your password manager.
- Before flipping the repo to public visibility, run the checklist below.

## Public release checklist

- [ ] `gitleaks detect --source . --verbose` passes on full history
- [ ] No secrets in any tracked file (tokens, keys, IDs, passwords)
- [ ] `.env.example` files have placeholder values only
- [ ] All development secrets rotated
- [ ] CI includes secret detection job

## File organisation

See [ARCHITECTURE.md](ARCHITECTURE.md) for the layered structure and the
rationale. Place new content in the layer it belongs to:

- New service (Jellyfin, Vaultwarden…) → `services/<name>/`
- Host-level setup (kernel, swap, users) → `bootstrap/`
- Network plumbing (tunnel, VPN, reverse proxy) → `network/`
- Storage / disks / backups → `storage/`
- Decisions worth recording → `docs/decisions/<NNNN>-<slug>.md` (ADR format)

## After every PR merge

- `git checkout main && git pull`
- Delete the local branch: `git branch -d <branch>`
- Prune remote refs: `git remote prune origin`
- Update [PROJECT_LOG.md](PROJECT_LOG.md) with a dated entry summarising
  the change and the PR number.
