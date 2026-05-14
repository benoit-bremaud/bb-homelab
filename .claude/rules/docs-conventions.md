---
paths:
  - "**/*.md"
---

# Documentation conventions — bb-homelab

Project-specific conventions for any documentation work in this repo.
This rule **extends** the agent-agnostic brief in
[AGENTS.md](../../AGENTS.md) and the global rules in
`~/.claude/CLAUDE.md`. When they conflict, the order of precedence is:
this rule > AGENTS.md > global.

## Language convention

Documentation is split into three categories with different language
rules:

- **Category A — human-facing docs : French**
  - `README.md` (root), `ARCHITECTURE.md`
  - `bootstrap/*.md`, `network/*.md`, `services/*/README.md`,
    `storage/*.md`
  - ADRs in `docs/decisions/`
- **Category B — agent-facing : English**
  - `AGENTS.md` (read by any AI tooling), `CLAUDE.md`
  - The modular rules in this `.claude/rules/` directory
- **Category C — workflow / audit artifacts : English**
  - `CONTRIBUTING.md` (referenced from AGENTS.md, kept in sync with EN
    commit conventions)
  - `PROJECT_LOG.md` (references EN commit messages and PR titles;
    keeping it FR would create a confusing bilingual audit trail)

Cross-references between categories are fine — links resolve regardless
of file language.

## Markdown style

Linter: `markdownlint-cli2`, config in `.markdownlint-cli2.jsonc`.

Five rules are enforced by CI (workflow `markdownlint.yml`):

- `MD022` — blank lines around headings
- `MD031` — blank lines around fenced code blocks
- `MD032` — blank lines around lists
- `MD040` — fenced code blocks must declare a language
- `MD041` — first non-frontmatter line must be a top-level heading

Known false positives that CI tolerates but local CLI flags:

- `MD060` (table column style) — newer CLI flags `|---|---|` dividers
  even though they are valid Markdown
- `MD004` (list style) — a `+` at column 3 of a continuation line gets
  parsed as a sub-bullet marker; rewrite to keep `+` away from
  column-1 / column-3 positions

Before commit, run:

```bash
npx -y markdownlint-cli2 --fix '**/*.md'
```

## ADR pattern (Architectural Decision Records)

Location: `docs/decisions/`
Format: `NNNN-slug.md` where `NNNN` is a monotonic 4-digit sequence.
**Never delete an ADR.** If a decision is reversed, write a new ADR
that supersedes the previous one.

Required sections (in order):

1. Title (`# ADR NNNN — <title>`)
2. **Status** (Accepted, Superseded, Deprecated)
3. **Date** (`YYYY-MM-DD`)
4. **Context** — what triggered this decision
5. **Decision** — what was chosen
6. **Consequences** — positive + negative
7. **Alternatives considered** — what was rejected and why
8. **Refs** — issue numbers, related ADRs, implementation paths

Update `docs/decisions/README.md` index whenever you add a new ADR.

Examples: [ADR 0001](../../docs/decisions/0001-dip-layering.md) (DIP
layering), [ADR 0002](../../docs/decisions/0002-caddy-reverse-proxy.md)
(Caddy reverse proxy).

## PROJECT_LOG discipline

The operational journal is `PROJECT_LOG.md` at the repo root. Every PR
merged on `main` gets a dated entry, in real time per merge (not
batched at end of week).

Reviewer attribution convention (since PR #74):

- Use `automated review (Must Have):`, `automated review (Should Have):`,
  `automated review (Re-review):`, `automated review (Disagree):`
- **Never** use named AI tools (`codex (...)`, `Copilot (...)`,
  `GPT (...)`) — those are AI attribution violations per
  [security-invariants](security-invariants.md).

History tables (in `BACKUP.md`, etc.) are an exception — they may
record dates + outcomes without reviewer names.

## Cross-references

Use relative markdown links: `[AGENTS.md](../../AGENTS.md)`.

**markdownlint does not verify that local link targets resolve** —
rule `MD042` (`no-empty-links`) only catches empty `[]()` link syntax,
not whether `../../AGENTS.md` actually exists. Broken-link detection
requires a dedicated tool like
[`markdown-link-check`](https://github.com/tcort/markdown-link-check)
or [`lychee`](https://github.com/lycheeverse/lychee). Until one is
added to CI, verify links manually before commit.

For external links, prefer full URLs over redirects to avoid silent
breakage when the redirect target changes.
