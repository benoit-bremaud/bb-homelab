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

### PR #33 merged: bootstrap CI security & quality workflows

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
- **Review fixes**: gitleaks switched to CLI mode (action 403'd on
  default token); markdownlint MD040/MD031 errors fixed across docs;
  yamllint workflow `strict: false` to honour the `level: warning`
  config intent.
- **Closes**: #32
- **Merge**: `e9c2cd5`

### Issue #2 closed (no PR)

- **What**: Closed as fully delivered by PR #31 — ARCHITECTURE.md
  already ships the 6-layer DIP table + request walkthrough, and
  ADR 0001 records the layering decision.

### PR #34 in progress: bootstrap script for fresh Pi setup

- **What**: Adds `bootstrap/bootstrap.sh`, an idempotent shell script
  that takes a freshly flashed Raspberry Pi OS Lite installation to a
  "ready to run services" baseline: apt update/upgrade, install of
  baseline tools (curl, htop, smartmontools, ufw, unattended-upgrades),
  Docker via the official convenience script, user added to the docker
  group, swapfile, timezone (default Europe/Paris), hostname (default
  bb-homelab), unattended security upgrades enabled.
- **Why**: Recovery from a dead SD card or first boot of a fresh Pi
  must take minutes, not hours. Encodes the manual procedure that was
  in `bootstrap/README.md` so it cannot drift.
- **Follow-up** (PR #35): six post-merge review points addressed —
  Docker apt repo (GPG-verified, distro-aware path for debian /
  raspbian / ubuntu), real systemd detection via
  `[ -d /run/systemd/system ]` for timezone/hostname steps, `#clear`
  directive on `Origins-Pattern` so security-only is truly enforced
  (not additive), removal of the over-broad Raspbian pattern, truthful
  comment on `Automatic-Reboot "false"`.
- **Closes**: #3
- **Merges**: `7673bb2` (#34), `6b25c54` (#35)

### PR #36 in progress: SSH hardening script

- **What**: Adds `bootstrap/harden-ssh.sh`, an idempotent script that
  disables password SSH, disables root login, enforces public-key
  auth, validates the new sshd_config with `sshd -t` before reload,
  and configures `ufw` to allow port 22 (scope: any | LAN cidr |
  Tailscale CGNAT).
- **Safety**: refuses to run if the target user has no
  authorized_keys (prevents lock-out), backs up sshd_config before
  edit, uses `reload` not `restart` so the live SSH session survives,
  prints clear instructions to verify in a new terminal before
  closing the original one.
- **Why deliberately separate from bootstrap.sh**: misconfiguring SSH
  on a remote host = lock-out. Splitting the two scripts lets the
  user verify key-based SSH works first, then opt into hardening.
- **Closes**: #4 (when merged).
