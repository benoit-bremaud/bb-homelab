# Local review — bb-homelab (branch diff main...docs/162-ufw-nest-ha-audio)

- Date: 2026-10-28
- Commit: 975c301 (gate re-run on this head on 2026-10-29; the next commit only updates this report)
- Scope: branch diff `main...HEAD`
- Checks run: docs · security · correctness (tests: docs only)
- Verdict: ship as-is after the fixes below · Must 2 (all fixed) · Should 0 (all fixed) · Nice 0 (issue)

## Pre-merge gate (head SHA 975c301)

| Step | Result |
|---|---|
| 1 Tests | N/A: docs only |
| 2 Coverage | N/A (no code) |
| 3 SonarQube | ✅ PASSED |
| 4 Secrets | ✅ gitleaks clean (`--log-opts=--all`) · no tracked .env · diff read: no IP, MAC or name added |
| 5 QA pass | ✅ smoke: the Nest fetches HA audio on the LAN; the ProBook (not allowed) still times out on 8123 |

Other checks: live: `ufw status numbered` shows rule 2 `8123/tcp ALLOW IN <nest-ip>`.

- Gate: **GREEN — push authorised**; merge after CI and the owner's approval

## PR review (automated review)

- `docs/architecture/review-local.md:9` `[process]` (automated review, P1) · gate recorded on an earlier SHA than the head · **fixed**: gate re-run on the head below

## 🔴 Must Have

- `docs/security/AUDIT.md:25,95,146` `[docs]` · UFW record contradicted itself and R10 ignored the new exception · **fixed** in 9e3cddd
- `docs/security/AUDIT.md:25,148` `[security]` · tailnet address published (pre-existing) · **fixed** here; repo-wide scrub tracked in #163 (owner MCDA 435: placeholder, history kept)

## 🟡 Should Have

_None._

## 🔵 Nice to Have

_None._

## ⚪ Disagree / Intentional

_None._

## Per-dimension summary

- Design: no over-engineering; one compose service, one script, one firewall rule.
- Docs: consistent across confiture, home-assistant and bb-homelab (issue numbers, MCDA totals, placeholders).
- Tests: no executable code in the diff.
- Security: Piper loopback only and non-root; 8123 open to the Nest only; residual LAN risk documented.
- Correctness: template path and languages verified live (`fr` for the agent, `fr_FR` for Piper).
