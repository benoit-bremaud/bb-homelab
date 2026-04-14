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

### PR #36 merged: SSH hardening script

- **What**: `bootstrap/harden-ssh.sh` locks SSH down (no password, no
  root, key-only, UFW allows 22 with configurable scope any / LAN
  CIDR / Tailscale CGNAT). Lock-out-proof: refuses to run without
  authorized_keys, validates with `sshd -t` before reload, uses
  reload (not restart) so the live session survives.
- **Deliberately separate from bootstrap.sh**: misconfiguring SSH on
  a remote host = lock-out. Splitting the two scripts lets the user
  verify key-based SSH works first, then opt into hardening.
- **Review fixes** (7 comments addressed in one commit): source of
  truth switched to `sshd -T` (authoritative effective config,
  resolves Include + Match last-wins), awk-based authorized_keys scan
  handles option-prefixed entries (`from=…`, `command=…`, `restrict`),
  lazy backup only on real change (no more clutter on no-op re-runs),
  CIDR regex validation + tokenised ufw call (no word-splitting of a
  single string), comment-out-all-duplicates + append-canonical so our
  line wins regardless of Include ordering.
- **Closes**: #4
- **Merge**: `e6df8dd`

### PR #37 in progress: Tailscale install script

- **What**: `network/install-tailscale.sh` installs Tailscale from
  the official signed apt repository (GPG-verified), then runs
  `tailscale up` so the user authenticates the device in a browser
  against their Tailscale account. Idempotent: already-installed and
  already-connected cases are detected and skipped.
- **Why**: Remote access to the homelab without port forwarding,
  without a public IP, and without a domain. Free for personal use
  (up to 100 devices + 3 users). Prerequisite for inviting the circle
  of trust (family / theatre troupe) to reach specific services.
- **Companion doc**: `network/tailscale.md` documents device-side
  install on laptops and phones, two invitation patterns (node
  sharing vs tailnet users), and the follow-up command to tighten
  SSH to the tailnet only
  (`SSH_UFW_SCOPE=tailscale bash bootstrap/harden-ssh.sh`).
- **Closes**: #5
- **Merge**: `6f68134`

### Milestone — Raspberry Pi 5 first-boot + Tailscale online

- **What**: First physical deployment of the homelab on a fresh RPi 5 +
  32 GB microSD. At the end of the session the Pi runs 24/7 on ethernet
  at `192.168.1.216` and is reachable from anywhere via Tailscale at
  `100.121.134.61` (tailnet `bbd.concept@gmail.com`). SSH uses
  public-key auth only, sudo requires a password, Docker is installed
  and validated with `hello-world`, swap (2 GB) + unattended-upgrades
  (security origins only) are active.
- **Why**: This is the first concrete milestone of the project — the
  `bb-homelab` repo scripts (`bootstrap.sh`, `harden-ssh.sh`,
  `install-tailscale.sh`) are proven end-to-end on real hardware, not
  just in CI.
- **Gotchas encountered (fixes to roll back into docs via issue #38)**:
  - **rpi-imager silently failed to inject its OS customisation** into
    `bootfs/user-data`; the file shipped contained the default Ubuntu
    template with every directive commented out. Had to write the
    cloud-init `user-data` by hand (hostname, user with `$6$...`
    password hash, ssh_authorized_keys, timezone, keyboard,
    `ssh_pwauth: false`).
  - **Pi OS Bookworm's sshd is disabled by default** unless the `ssh`
    sentinel file is present on bootfs OR an explicit
    `systemctl enable ssh` runs via cloud-init `runcmd`. Both were
    added to unblock the first boot.
  - **`openssl passwd -6` without argument is fragile** (silent input,
    "Verify failure" on typos). Quoted-argument variant
    `openssl passwd -6 "password"` is reliable (clean history after).
  - **Pi OS ships a NOPASSWD sudoers rule** at
    `/etc/sudoers.d/010_pi-nopasswd` for the main user — removed after
    bootstrap for security.
  - **git is NOT pre-installed on Pi OS Lite** — needs
    `sudo apt install -y git` before cloning the repo (or a prior
    `bootstrap.sh` run which installs it as part of baseline tools).
  - **Tailscale `tailscale up` printed no URL interactively** (some
    buffering / output issue in this build). Worked flawlessly via
    the admin console auth-key flow
    (`sudo tailscale up --auth-key=tskey-... --hostname=bb-homelab`).
- **Follow-ups**:
  - Issue #38 — write `bootstrap/FIRSTBOOT.md` documenting the proven
    recipe top-to-bottom, now that we know what actually works.
  - Consider baking the `sudo rm /etc/sudoers.d/010_pi-nopasswd` step
    into `bootstrap.sh` or a dedicated `harden-sudo.sh`.
  - Optionally tighten SSH to tailnet-only via
    `SSH_UFW_SCOPE=tailscale bash bootstrap/harden-ssh.sh` (deferred —
    we keep LAN SSH during initial migration work).
