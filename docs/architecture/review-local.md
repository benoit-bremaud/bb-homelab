# Local review — bb-homelab (branch diff docs/129-align-rules-with-global, uncommitted)

- Date: 2026-10-22
- Commit: 0127b7e (base) + uncommitted changes
- Scope: rules, skills and docs alignment (issue #129), mode `--push`
- Checks run: docs · security · correctness (design and tests: not applicable, no code)
- Verdict: fix Must Have first · Must 4 · Should 6 · Nice 5 (all Must and Should applied after the review)

## Pre-merge gate (head SHA not yet committed)

| Step | Result |
|---|---|
| 1 Tests | N/A: no test suite in this repo; linters run instead (markdownlint: only the known MD060 false positive; yamllint not runnable locally, no YAML changed) |
| 2 Coverage | tests N/A (docs/rules diff) · docs: every link resolves, no new service |
| 3 SonarQube | not run (runs in CI on the PR) |
| 4 Secrets | ✅ gitleaks clean (working tree and origin/main..HEAD) · no tracked .env · diff read: nothing sensitive |
| 5 QA pass | skipped (`--push` mode) |

- Gate: not evaluated (push review only)

## 🔴 Must Have

- `CLAUDE.md:21` `[docs]` · still says the security rule is "attribution policy (strict)" · change to "allowed, kept sober".
- `CONTRIBUTING.md:43,45` `[docs]` · names Copilot in a Category C doc, against the new rule · reword to "an automated reviewer" and keep the UI path as a literal label or "code-review settings".
- `AGENTS.md:3`, `docs-conventions.md:11`, `CLAUDE.md:34-36` `[docs]` · precedence is stated three different ways · state one order once, mirror it.
- `AGENTS.md:44` vs `docs-conventions.md:23-27` `[docs]` (pre-existing) · "docs in English" contradicts the FR/EN split · "commit messages and code comments in English; docs follow the FR/EN split".

## 🟡 Should Have

- `AGENTS.md` §7 `[docs][security]` · attribution bullet omits the exceptions listed in security-invariants.md · add a pointer to that file.
- `security-invariants.md` `[security]` · say that PR comments and PROJECT_LOG stay free of tool names; footer is for PR descriptions only, trailer for commits.
- `docs-conventions.md:23-27` `[docs]` · `docs/architecture/qa/` and `docs/architecture/**` missing from Category A.
- `docs-conventions.md:12-16`, `CLAUDE.md` `[docs][security]` · "to be confirmed by the owner" is an open question inside a rule, and invites a visibility flip · record the decision or link an issue; add "never change visibility without an explicit owner request".
- `AGENTS.md:49`, `pr-workflow` `[docs]` · `docker compose config` and `caddy validate` are manual, not CI · say so; list tests/doc-coverage substitutions as known deviations.
- `CLAUDE.md:70`, `AGENTS.md:46` `[docs]` · `review-local` is a command in `~/.claude/commands/`, not a skill · write `/review-local`.

## 🔵 Nice to Have

- `pr-workflow` description `[docs]` · "strict 6-step merge gate" now sits next to a pre-merge gate: add one sentence on how they chain.
- `AGENTS.md` §4 `[docs]` · merge question copied in three places (AGENTS, skill, CONTRIBUTING summary) · keep the verbatim text in the skill only; add "if one fails, say which" for parity.
- `pr-workflow` merge gate step 2 `[docs]` · "Copilot or codex" · "the automated reviewers".
- `pr-workflow` post-merge `[docs]` · memory compression restated · link to the global source instead.
- `qa/README.md` `[docs]` · step 1 has no command for checking relative links.

## ⚪ Disagree / Intentional

- `pr-workflow:42` `[docs]` · `.codex` filename and "Copilot or codex" in a Category B skill · covered by the security-invariants exceptions.
- "SonarCloud" vs "SonarQube" · the repo runs SonarCloud, the global rule says SonarQube · kept as is, both name the same gate.

## Per-dimension summary

- Design: N/A, no code · Docs: stale line, one brand mention, two contradictions · Tests: N/A · Security: no weakened invariant, merge sentence identical to the global one, no secret · Correctness: links and frontmatter valid.
