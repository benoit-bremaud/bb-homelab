# PROJECT_LOG — bb-homelab

Chronological operational logbook for the bb-homelab project. Every PR
merged, every architectural decision, every backlog reorganisation lands
here as a dated entry.

This is **not** a changelog (release-oriented). It is the day-by-day
journal that lets a future reader (or a future agent) reconstruct what
was done and why, by date.

---

## 2026-04-13

### Repo bootstrap

- **What**: Created the private GitHub repo `benoit-bremaud/bb-homelab`
  with CC BY-SA 4.0 license, 18 standard labels (priority / type / area),
  30 backlog issues spanning Foundation (P0), n8n migration (P1), media
  center (P2), project hosting (P3), robustness (P4), nice-to-have apps
  (P5), and pending decisions.
- **Why**: Centralise self-hosting work that previously lived in
  `impropedia-infra` and start scaling toward multi-service hosting
  (n8n, Jellyfin, brasse-bouillon, etc.) on a Raspberry Pi 5.
- **Decisions locked**:
  - DIP-aligned layered architecture (6 layers).
  - Visibility: private now → public later.
  - Documentation language: English.
  - `impropedia-infra` to be migrated under `services/n8n/` (issue #6).
  - Boot media: SD card to start, USB SSD upgrade tracked as decision #29.
  - Domain purchase deferred (decision #28); start with trycloudflare
    ephemeral + Tailscale.
  - Disk redundancy strategy deferred (decision #27).
  - Remote access for circle of trust: Tailscale (no domain needed).
- **Project board**: <https://github.com/users/benoit-bremaud/projects/48>

### PR #31 merged: bootstrap repo structure with DIP-aligned layers

- **What**: Initialised the repo skeleton — README, ARCHITECTURE
  (6-layer DIP table + request walkthrough), PROJECT_LOG, CONTRIBUTING
  (Conventional Commits + PR review procedure + public-release security
  checklist), four top-level folders (`bootstrap/`, `network/`,
  `services/`, `storage/`) each with a README scoping the layer and
  linking to the issues that will populate it, ADR 0001 documenting the
  layering choice, `.gitignore`.
- **Why**: Future issues need a place to land and a documented
  convention. The repo layout mirrors the architectural layers so any
  reader can locate concerns immediately.
- **Review**: 4 review comments addressed (sudo on apt, no
  curl-pipe-shell-as-root, no AI tooling references in CONTRIBUTING,
  use relative `../../issues` link).
- **Closes**: #1
- **Merge**: `f6cad1b`

## 2026-04-14

### PR #32 in progress: bootstrap CI security & quality workflows

- **What**: Adds eight GitHub Actions workflows covering secret
  detection (gitleaks), shell scripts (shellcheck), YAML (yamllint),
  Markdown (markdownlint-cli2), Dockerfiles (hadolint), and
  public-only checks (dependency-review, CodeQL, OSSF Scorecard).
  All third-party actions pinned by SHA. Public-only workflows gated
  with `if: github.event.repository.private == false` so they stay
  silent until the repo is published.
- **Why**: Per the global "CI Security Tooling — Standard for All
  Projects" rule, every project must ship the security baseline from
  day 1, before code starts piling up.
- **Closes**: #32 (when merged).
