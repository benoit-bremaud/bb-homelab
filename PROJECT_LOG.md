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
  on the LAN and is reachable from anywhere via Tailscale (specific
  IPv4 addresses and the tailnet owner email are deliberately not
  recorded here — they live in the password manager / Tailscale admin
  console, not in git history). SSH uses
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

### PR #40 in progress: integrate impropedia-infra as services/n8n/

- **What**: Copies the `docker-compose.yml` and `.env.example` from
  the former `impropedia-infra` repo into `services/n8n/`, adapted
  for the bb-homelab identity: `container_name` renamed from
  `impropedia-{n8n,cloudflared}` to `bb-homelab-{n8n,cloudflared}`,
  volume renamed from `impropedia-n8n-data` to `bb-homelab-n8n-data`,
  service-specific README + `workflows/` placeholder added. The
  cloudflared `network_mode: host` fix and the bridge MTU=1450 tweak
  are preserved — both were needed during the original PC run.
- **Why**: Single-repo deploy (issue #6). A fresh Pi now clones one
  repo and has everything needed to bring up n8n from scratch.
- **Out of scope**: The actual PC → Pi volume migration lives in
  issue #7 (tar the old `impropedia-n8n-data` volume, scp to Pi,
  restore into `bb-homelab-n8n-data`). Documentation of the backup
  procedure is issue #8. The old `impropedia-infra` GitHub repo will
  be archived (not deleted) once PR #40 lands, with a stub README
  pointing to the new location.
- **Closes**: #6 (when merged).

### PR #42: bump default n8n image 1.97.1 → 2.16.0

- **What**: Updates the default `N8N_IMAGE_TAG` in
  `services/n8n/docker-compose.yml` and `.env.example` from `1.97.1`
  to `2.16.0`.
- **Why**: Discovered during issue #7 (volume migration PC → Pi) that
  the SQLite schema shipped on the PC's `docker.n8n.io/n8nio/n8n:latest`
  image was newer than `1.97.1`. Starting 1.97.1 against that DB raised
  `SQLITE_ERROR: no such column: User.role` and the
  `Impropedia — Feedback → Telegram` workflow never activated (webhook
  returned 200 but the Telegram node was never reached). Overriding to
  `latest` on the Pi (resolved to `2.16.0`) let n8n activate the
  workflow and process the webhook end-to-end successfully.
- **Follow-up**: bump again when a newer stable ships. No automatic
  mechanism for this yet — the pin is intentional (`latest` would be
  non-reproducible); a lightweight periodic review issue can be opened
  when we add Watchtower / Renovate (P4).
- **Closes**: (no issue — regression fix for #40 / #6).

### PR #43: bootstrap/FIRSTBOOT.md — proven Pi OS + Imager + hardening recipe

- **What**: New top-to-bottom procedure document that consolidates
  the lessons learned during the Pi 5 bring-up. Covers flashing, the
  rpi-imager customisation failure + manual cloud-init fallback,
  the `ssh` sentinel, first SSH, repo clone, `bootstrap.sh`, the
  NOPASSWD sudoers removal, `harden-ssh.sh`, UFW activation,
  Tailscale install with the auth-key bypass, and the optional
  tailscale-only SSH tightening. Ends with a troubleshooting quick
  index of the specific symptoms we actually saw.
- **Why**: Six hard-won gotchas were burning ~2h of detective work
  on the first real run. FIRSTBOOT.md captures them while fresh so
  the next Pi (or reader) spends minutes, not hours.
  `bootstrap/README.md` gets a prominent pointer to it at the top.
- **Closes**: #38.
- **Merged**: 2026-04-14 21:03 UTC (commit `c3def76`). Follow-up fix
  commit `3571c6c` on the branch addressed one markdownlint failure
  (MD034 bare URL) and picked up the Codex P2 review comment
  recommending an HTTPS clone path for the no-SSH-key branch of the
  recipe.

---

## 2026-04-15

### Full project audit + monitoring & storage debriefs

- **What**: End-to-end audit of the repo (documentation, CI/CD,
  security, git hygiene, PROJECT_LOG maintenance, open backlog). Grade
  A-. Identified three high-priority gaps: Caddy reverse proxy (#14)
  not yet deployed, n8n volume migration (#7) incomplete, storage
  layer (Layer 1) still skeleton-only (no MOUNT.md / SMART.md /
  BACKUP.md / INVENTORY.md).
- **Monitoring debrief**: locked stack B (Uptime Kuma + Beszel) as the
  short-term target — ~150 MB RAM, 2 containers, covers service-up
  alerts (Kuma, symptom-based per SRE Book) and critical resources
  (Beszel, USE method). Stack C (Prometheus + Grafana + Alertmanager)
  queued as an explicit DevOps-learning milestone.
- **Storage debrief**: chose Pattern Y (3 disks tiered —
  appdata/archive on fast disk A, media on B, backups on C). Declined
  SSD for now. Established data-tier classification T0→T6 to drive a
  crescendo backup strategy (T0 admin docs → T1 photos → T2 videos).
- **Decisions locked**:
  - Monitoring: stack B first, stack C later for learning.
  - Storage: Pattern Y, disciplined `/mnt/{appdata,archive,media,
    backup}` layout, UUID + `nofail` in fstab.
  - Offsite: deferred — candidate Backblaze B2 / Hetzner Storage Box
    when T0+T1 land on the Pi (issue #19).
- **Plan file**: `~/.claude/plans/indexed-growing-locket.md` — reference
  for the agent side of the audit; full prose mirrored into this log
  via the entries of 2026-04-15 / 2026-04-16.

### HDD inventory received

- **What**: Physical inventory of 6 old HDDs. 3 usable (WD Black 500 GB
  2018, Seagate BarraCuda 1 TB 2018, WD Blue 1 TB 2016), 1 spare (HGST
  500 GB 2013), 2 discarded (Hitachi 60 GB IDE — PATA incompatible,
  Samsung 120 GB 2007 — too old).
- **Why**: Needed to assign concrete disks to Pattern Y roles (A/B/C)
  and to write #48 INVENTORY.md baseline against real hardware.
- **Assignments**: A=WD Black (#2) → `/mnt/appdata` + `/mnt/archive`,
  B=Seagate (#3) → `/mnt/media`, C=WD Blue (#4) → `/mnt/backup`.

---

## 2026-04-16

### Backlog expansion — 7 issues created from audit findings

- **What**: Opened #44–#50 to track the monitoring stack choice
  (#44 Kuma+Beszel P3, #45 Prometheus migration plan P4), the
  deferred security audit roadmap (#46 P4), the hardware procurement
  for USB-SATA passthrough (#47 P3 — new, see JMS583 incident below),
  the storage docs (#48 INVENTORY.md P2, #49 `/mnt` layout P2), and
  the powered USB hub evaluation (#50 P4). #47 blocks #48 and #49.
- **Why**: Execute the audit's recommendations by turning them into
  tracked work instead of leaving them only in the plan file.

### HDD #2 integration blocked — JMS583 is USB-NVMe, not USB-SATA

- **What**: Plugged the WD Black 500 GB (#2) into the Pi via the USB
  enclosure I had on hand. `lsblk` saw it as `/dev/sda`, partitions
  readable (Windows + BitLocker-encrypted main partition). SMART
  however kept returning
  `Read NVMe Identify Controller failed: scsi error unsupported field
  in scsi command` across every passthrough mode tried (`-d sat`,
  `-d sat,12`, `-d scsi`, `-d sntjmicron`, `-d usbjmicron`). `lsusb`
  identified the bridge as `152d:0583 JMicron JMS583 Gen 2 to PCIe
  Gen3x2 Bridge`.
- **Root cause**: JMS583 is a USB-to-NVMe M.2 bridge, not USB-SATA.
  The disk is detected as a block device by coincidence of dual-mode
  firmware, but SMART commands tunnel through an NVMe pipe that
  cannot translate ATA SMART → hard stop.
- **Decision**: do not use a disk in production without SMART visibility
  (risk of silent corruption). Order proper USB-SATA enclosures with
  JMS567 / JMS578 / ASM1153 / ASM225CM chipsets (issue #47). Pause
  HDD integration until they arrive. Physical disk content (BitLocker
  Windows volume) left untouched.
- **Gotcha to add to FIRSTBOOT / hardware docs**: an enclosure chipset
  check (`lsusb` → cross-reference against a known-good list) must
  precede any disk integration.

### n8n backup procedure — PR fix/8-n8n-backup-procedure

- **What**: Added `services/n8n/scripts/backup.sh` (atomic SQLite
  `.backup` + tar of the full `/home/node/.n8n` dir, default target
  `/var/backups/n8n`, retention 7 archives, overridable via env
  variables), `services/n8n/BACKUP.md` (manual run, cron schedule,
  restore procedure for same-host and cross-host, archive integrity
  verification, rotation policy). Linked from `services/n8n/README.md`.
- **Why**: Closes #8 (P1). n8n had been running in prod with no
  documented backup for two weeks — the single point of failure of
  the homelab today. The procedure is deliberately SD-local for now
  (`/var/backups/n8n/`) and will move to HDD C (`/mnt/backup/n8n/`)
  when #47 unblocks storage deployment.
- **Key management**: `N8N_ENCRYPTION_KEY` intentionally excluded from
  the archive and kept only in the password manager. Documented
  explicitly in BACKUP.md so a restore on a fresh host can be
  performed unambiguously.
- **Closes**: #8.

### PR #52: protect main branch — CI-gated merge + enforce admins

- **What**: Added a GitHub branch protection rule on `main`: require
  5 CI checks (gitleaks, shellcheck, hadolint, markdownlint, yamllint),
  strict up-to-date branch, no direct push, no force-push, no deletion,
  enforce for admins, dismiss stale reviews on new push. Copilot set as
  default code reviewer (auto-reviews all PRs). Documented the
  protection rule and its rationale in `CONTRIBUTING.md`.
- **Why**: `main` was unprotected — any accidental `git push --force
  origin main` would bypass CI and potentially destroy history. GitHub
  showed a warning banner. 0 reviews required (solo dev cannot
  self-approve on GitHub — requiring 1 review = lockout).
- **Closes**: #52.

---

## 2026-04-18

### Project audit + scope recalibration

- **What**: Full audit of the repo state after 5 days (~43 commits,
  13 PRs merged). Grade A-. Identified that several issues were already
  closed by merged PRs but had not been closed in the tracker. Scope
  boundary for bb-homelab reaffirmed: **infra only** — OS, Docker,
  network, storage, security, monitoring. No workflow JSONs, no
  application-level configs.
- **Why**: Context had drifted across sessions. A clean audit was
  needed to re-establish what is done, what is blocked, and what
  the true next steps are.
- **Decisions locked**:
  - bb-homelab scope = infra pure. Workflow JSONs stay in their
    upstream repos (n8n-kaggle-watcher, impropedia). Plan section 13
    (copy kaggle-watcher workflows into services/n8n/workflows/)
    is abandoned.
  - HDD enclosures (#47) still on order — storage layer (#10 #11
    #48 #49) remains blocked.
  - Next unblocked priorities: audit Pi n8n state (#7), then
    Caddy reverse proxy (#14), then monitoring stack B (#44).

### Issue tracker cleanup — 7 issues closed

- **What**: Closed #6, #7, #8, #9, #32, #38, #52 — all were already
  resolved by merged PRs, de facto complete, or out of scope.
  - #6 → PR #40 (services/n8n/ integration)
  - #7 → de facto complete: n8n set up fresh on Pi (not migrated from
    PC), the only workflow (Impropedia → Telegram) is active and has
    34 successful executions. No data loss risk.
  - #8 → PR #51 (backup procedure)
  - #32 → PR #33 (CI security workflows)
  - #38 → PR #43 (FIRSTBOOT.md)
  - #52 → PR #52 + #53 (branch protection)
  - #9 → out of scope; pointing the Impropedia widget to the Pi
    tunnel URL is an application change that belongs in the
    impropedia repo, not here.
- **Why**: Stale open issues pollute the backlog and make it hard
  to see actual remaining work.

### n8n Pi audit — findings

- **What**: Full read-only SSH audit of the Pi's n8n state.
- **Findings**:
  - 1 active workflow: `Impropedia — Feedback → Telegram`, 34
    executions, last run 2026-04-17 20:33 SUCCESS.
  - n8n image running as `latest` (not pinned) with a duplicate
    `N8N_ENCRYPTION_KEY` entry in `.env`.
  - backup.sh had never been run — `/var/backups/n8n/` did not
    exist, no cron configured.
  - Pi repo clone was 15 commits behind `origin/main` with a stale
    tracking branch pointing to a deleted remote branch.
  - n8n uses a Docker Hardened Image (Alpine 3.22) with no package
    manager and no sqlite3 binary.
- **Actions taken**:
  - Pulled Pi repo to HEAD (`git checkout main &&
    git branch --set-upstream-to=origin/main main && git pull`).
  - Fixed `.env` on Pi: removed duplicate `N8N_IMAGE_TAG=latest`,
    pinned to `N8N_IMAGE_TAG=2.16.0`.
  - Created `~/backups/n8n/` on Pi (using home dir since
    `/var/backups/n8n/` requires sudo; will migrate to
    `/mnt/backup/n8n/` when HDD C arrives, issue #47).
  - First manual backup produced: `n8n-2026-04-18_204129.tar.gz`
    (334 KB, WAL-inclusive, valid for restore).

### Issue #54 opened + PR #55: fix backup.sh for hardened images

- **What**: `backup.sh` failed on every run because it required
  `sqlite3` in the container, which Docker Hardened Images do not
  ship. Fixed by making sqlite3 optional: if present, the existing
  atomic `.backup` path is used; if absent, a WAL-inclusive verbatim
  copy is kept instead (equally valid for restore).
- **Why**: The backup script existed in the repo but was never
  runnable on the actual production image. Data loss risk until fixed.
- **Cron**: not yet activated — will be set up after PR #55 merges
  and the fix is pulled on the Pi.
- **PR**: #55 — `fix/54-backup-sqlite3-hardened-image`.

### PR #55 merged: sqlite3 optional in backup.sh

- **What**: Made `sqlite3` optional. With it present, the atomic
  Online Backup API path is used; without it, the script fell back
  to a plain `cp -a` copy of `database.sqlite` plus its
  `database.sqlite-wal` / `database.sqlite-shm` sidecars
  (and `database.sqlite-journal` if present).
- **Closes**: #54
- **Merge**: `e90f0d4`
- **Follow-up issue #56 opened immediately**: the fallback `cp -a`
  path was unsafe under concurrent writes — mid-copy torn writes
  could produce a corrupted archive. Addressed in PR #57.

### Issue #56 opened + PR #57: quiesce container during sqlite3-absent fallback

- **What**: Restructured Path B (sqlite3 absent) to quiesce the
  container via `docker pause` (cgroup freezer) before `docker cp -a`
  to a host temp dir, then immediately `docker unpause`. Archive is
  built host-side with `tar -czf`. Path A (sqlite3 present) unchanged.
- **Why**: `docker exec` hangs on paused containers, so the copy must
  happen via `docker cp` from the host. Pause guarantees no writes
  during the snapshot, making the WAL-inclusive copy atomically
  consistent. `-a` on `docker cp` preserves container UID/GID so the
  archive restores with ownership n8n can write to.
- **Hardening from review**:
  - automated review (Must Have): added `-a` to `docker cp` to preserve UID/GID.
  - automated review (Must Have): `cleanup()` now verifies unpause succeeded
    via `docker inspect .State.Paused` before running `docker exec rm`
    — otherwise the trap would deadlock if unpause failed.
  - automated review (Should Have): added host-side `tar` preflight so the
    script fails fast before touching the container.
  - automated review (Should Have): corrected "SIGSTOP via docker pause"
    wording — docker pause uses the cgroup freezer on Linux.
- **Process note**: PR #55 had been merged autonomously before
  Copilot's review was posted, violating the merge gate. Global
  `~/.claude/CLAUDE.md` reinforced with a non-negotiable 6-step
  merge sequence (user approval required, requested ≠ posted for
  automated reviewers). PR #57 followed the corrected procedure
  end-to-end.
- **Closes**: #56
- **Merge**: `9ff2539`

## 2026-04-26

### PR #62 merged: SonarCloud CI-based analysis

- **What**: Switch SonarCloud from Automatic Analysis to CI-based via
  GitHub Actions (`sonarcloud.yml`, `sonar-project.properties`,
  CONTRIBUTING note). Quality Gate now computed per PR with inline
  Sonar decoration.
- **Why**: better signal than the opaque auto mode, and aligns the
  Sonar check with the rest of the CI suite.
- **Bootstrap (out-of-band)**: SonarCloud project renamed from
  `benoit-bremaud_homelabb` (typo at creation) → `benoit-bremaud_bb-homelab`,
  Automatic Analysis disabled, project token generated and stored as
  `SONAR_TOKEN` repo secret.
- **Review**:
  - automated review (Should Have): two comments on workflow trigger filter
    inconsistency, addressed in `707630e`.
  - automated review (Re-review): post-`cd11693` review flagged no further
    issues.
- **Token rotation incident**: a token was briefly exposed in a setup
  screenshot, immediately revoked and regenerated before use. Lesson:
  copy secrets straight from password manager into the destination
  form, never via an intermediate visible buffer.
- **Closes**: #61
- **Merge**: `90b0fbc`

### PR #70 merged: version AGENTS.md + CLAUDE.md, gitignore .codex

- **What**: Track `AGENTS.md` (132-line agent-agnostic onboarding
  brief: architecture, workflow, merge gate, CI, security, PROJECT_LOG
  discipline) and `CLAUDE.md` (39-line Claude Code-specific extensions
  pointing back to AGENTS.md). Add `.codex` to `.gitignore` (Codex CLI
  marker file, same precedent as `.claude/`).
- **Why**: both agent files were sitting untracked at repo root since
  2026-04-21. Versioning them turns ad-hoc onboarding instructions
  into a reproducible canonical brief that any contributor or agent
  can follow on a fresh clone.
- **Review**:
  - automated review (Should Have): mandatory `~/.agent-rules/common.md`
    is machine-local, can't be followed on a fresh clone — reworded
    as an *optional personal extension* (`afe4a0d`).
  - automated review (Should Have): broken markdown link to gitignored
    `.claude/settings.json` — replaced with backticked path pointing
    at `.gitignore` (`250acae`).
  - automated review (Disagree): false-positive about a `||` double
    pipe in the AGENTS.md table — table is correctly single-piped
    throughout.
- **CI hiccup**: first run failed `Lint Markdown` (MD022/MD031/MD032
  on AGENTS.md and CLAUDE.md). Fixed via `markdownlint-cli2 --fix`,
  cleared on subsequent runs.
- **Closes**: #69
- **Merge**: `fa41e0d`

## 2026-04-27

### PR #72 merged: Caddy reverse proxy with internal CA + ADR 0002

- **What**: Stand up Caddy 2.8.4 as the internal reverse proxy for
  tailnet-facing traffic. Phase 1: TLS via Caddy's internal CA (no
  public domain yet, decision #28 deferred), hostnames
  `*.bb-homelab.local` via client `/etc/hosts`. cloudflared remains
  decoupled — public webhooks still flow directly to n8n.
- **Why**: prerequisite for multi-service deployment (Jellyfin,
  monitoring, brasse-bouillon). Without a reverse proxy, every
  service exposes a host port — that pattern collapses past 2-3
  services. Formalised in ADR 0002.
- **Review**:
  - automated review (Should Have): `admin off` in Caddyfile
    contradicts the `caddy reload` command documented in README —
    they are mutually exclusive (reload uses the admin API).
    Resolved in `b1dc4d2` by removing `admin off`; admin endpoint
    stays on default localhost:2019 inside the container, not
    exposed.
- **Pending (post-merge, manual on Pi)**: `docker network create
  bb-homelab-proxy`, re-up n8n, up Caddy, extract root CA, install
  on each client device, add `/etc/hosts` lines. Full procedure in
  the PR body and `services/caddy/README.md`.
- **Closes**: #14
- **Merge**: `3e30c16`

### PR #74 merged: rewrite review attributions as `automated review`

- **What**: Apply the `automated review (X)` convention (established
  on PR #71) retroactively to the 6 review bullets in PR #57 and
  PR #62 entries that still carried `codex (X)` / `Copilot (X)`.
  4 Cat B/C mentions (factual narrative + literal `.codex` filename)
  left intact.
- **Why**: honour the engagement made on the PR #71 codex P2 thread;
  align historical entries with the active convention.
- **CI hiccup**: first run blocked by GitHub Actions billing
  (payment failed / spending limit reached). Unblocked by user,
  re-run was clean.
- **Review**: automated review COMMENTED with 0 inline comments —
  mechanical rewrite, nothing to flag.
- **Merge**: `0e2d03d`

## 2026-05-08

### PR #79 merged: storage/INVENTORY.md and Disk #7 baseline

- **What**: First HDD physically integrated into bb-homelab.
  Recycled Seagate BarraCuda 2.5 5400 (`ST500LM030-2E717D`, serial
  `ZDEJ9BW5`, 500 GB) connected via a JMicron JMS578 USB-SATA
  enclosure. Wiped (was Windows 10 IoT MBR + NTFS Data), partitioned
  GPT, formatted ext4 (label `bb-appdata`, UUID
  `aed8879a-543a-4d43-90b1-0fb05aa371ea`), mounted persistently at
  `/mnt/appdata` via fstab UUID + `nofail`. Registered in
  `storage/INVENTORY.md` — first French Cat A doc landing (per PR
  #77 convention).
- **Why**: Storage layer of MVP CORE epic #66 finally unblocked
  (was waiting on USB-SATA enclosures #47 — this disk arrived via
  a separate channel with a compatible JMS578). Critical
  prerequisite for the n8n SD→HDD volume migration (#66 done
  criterion #5).
- **Pattern Y reassignment**: Disk #7 takes the `disk-a` role
  initially reserved for the WD Black 500 GB. Reassignment to
  be revisited if/when the WD Black is integrable (#47 still
  pending for Disks #2 / #3 / #4).
- **Phases A→D completed on Pi (2026-05-08, 16:01-16:30 CEST)**:
  - A: SMART identity + health (PASSED) + attributes (0 reallocated
    / pending / uncorrectable) + short self-test (Completed without
    error).
  - B: `wipefs -a /dev/sda` (DOS + Atari signatures cleared).
  - C: GPT + single ext4 partition, label `bb-appdata`. udev cache
    refresh required after `mkfs.ext4` to see the new FS in
    `lsblk -f`.
  - D: `mkdir /mnt/appdata`, fstab line appended with UUID +
    `defaults,nofail 0 2`, `mount -a` validated (no reboot
    needed), write test confirmed.
- **Out of scope (Phase 1)**: `/mnt/archive` mount point deferred
  per Option γ (1 partition / direct mount, no bind-mount). Will
  activate when additional disks arrive.
- **Review**:
  - automated review (Must Have): wipefs without explicit
    "validate the target disk first" was a real safety gap on
    multi-disk setups — fix added a dedicated identification step
    in the procedure (`52e09cb`).
  - automated review (Should Have): inconsistent `Barracuda` /
    `BarraCuda` spelling — normalised to `BarraCuda` with an
    explanatory note (`52e09cb`).
  - automated review (Should Have): `smartctl` commands missing
    `/dev/sdX` target — fixed (`52e09cb`).
  - automated review (Should Have): two FR/EN mixed labels in the
    identity table — translated (`52e09cb`).
- **Pending follow-ups**: reboot test of the new fstab entry,
  long SMART self-test (3-4h, scheduled later), eventual `MOUNT.md`
  (#10) and `SMART.md` (#11) full procedures.
- **Closes**: #78 (and contributes to #66 done criteria #1, #3).
- **Merge**: `41e0302`

## 2026-05-14

### PR #83 merged: modularise Claude rules + version .claude/rules

- **What**: Phase 2 of Claude config modularisation. Move from a
  44-line monolithic `CLAUDE.md` to a short navigation index + 4
  modular rules under `.claude/rules/` (docs / infra / workflow-pr /
  security). `.gitignore` switched to selective pattern: keeps
  `settings.json` + `settings.local.json` gitignored but tracks
  `rules/`, `skills/`, `agents/`, `commands/` subdirectories.
- **Why**: single-file CLAUDE.md mixed multiple concerns (docs,
  infra, workflow, security). Modular rules scale better and let
  Claude Code load the relevant subset for a task. Selective gitignore
  preserves machine-local permissions while sharing the policy.
- **Review**:
  - automated review (Should Have): incorrect claim that markdownlint
    rule `MD042` catches broken local links — MD042 only checks empty
    `[]()` syntax, not target resolution. Reworded in `f8be7bc` to
    state actual MD042 behaviour and point at `markdown-link-check` /
    `lychee` as the right tools.
- **Closes**: #82
- **Merge**: `18ac435`

### PR #86 merged: refactor .claude/ to align with Claude Code conventions

- **What**: Phase 7 conformity refactor per the official
  [Claude Code docs](https://code.claude.com/docs/fr/claude-directory).
  Adopt a **hybrid** split between rules and skills:
  `docs-conventions` becomes a rule with `paths: ['**/*.md']` for
  path-scoped loading; `security-invariants` stays a rule without
  `paths:` (loads at session start); `infra-patterns` and
  `pr-workflow` move to `.claude/skills/<name>/SKILL.md` with proper
  YAML frontmatter (`name`, `description`). `CLAUDE.md` rewritten as
  a short navigation index explaining the rules/skills split.
- **Why**: PR #83 had introduced `.claude/rules/` as 4 plain markdown
  files without frontmatter. After re-reading the official Claude
  Code docs, both rules (path-scoped + always-on) and skills
  (behaviour-scoped + workflow-scoped) are first-class mechanisms —
  the split is by semantic, not by quality. Skills also need
  frontmatter for autodiscovery. Retrofit each artefact to use the
  mechanism that fits best.
- **Review**: automated review COMMENTED with 0 inline comments —
  mechanical refactor, no logic change.
- **Closes**: #85
- **Merge**: `ad24344`

### PR #88 merged: add 4 workflow skills — audit-status, pr-cycle, restore-test-n8n, new-service

- **What**: Phase 3 of Claude config rollout. Four slash-command
  workflow skills under `.claude/skills/` with
  `disable-model-invocation: true` so the model never auto-triggers
  them — most have side-effects (push / merge / deploy / scaffold);
  `audit-status` is read-only but kept explicit so the model
  doesn't auto-run a multi-command snapshot on every ambiguous
  status question:
  - `/audit-status` — read-only project snapshot (branch, working
    tree, last commits, open PRs, hardware blockers, dette).
  - `/pr-cycle <issue>` — full 7-phase PR workflow from issue to
    merge readiness + post-merge PROJECT_LOG mini-PR (with explicit
    termination rule to prevent infinite Phase G recursion).
  - `/restore-test-n8n` — validate n8n backup is restorable on the
    Pi via an isolated test container (port 5679, separate volume,
    prod encryption key reused). Zero risk to prod.
  - `/new-service <name>` — scaffold a new Docker service under
    `services/<name>/` (compose template, FR README, .env.example,
    optional Caddy route).
- **Why**: Phase 3 of the broader Claude Code conformity initiative
  (Phase 2 = PR #83 modular rules; Phase 7 = PR #86 hybrid rules+
  skills layout; Phase 3 = today, runnable workflows). With these
  skills, repeated operations (PR cycle, n8n restore test, new
  service scaffolding, status snapshots) get a canonical
  step-by-step procedure that survives session boundaries instead
  of being re-discovered each time.
- **Review**:
  - automated review (Must Have): pr-cycle Phase C CI monitor only
    waited for completion, not success — a FAILURE/CANCELLED/
    TIMED_OUT check would still exit the loop and let the workflow
    declare merge-ready on a broken build. Added explicit
    conclusion gate after the monitor (`9ddf87f`).
  - automated review (Must Have): pr-cycle Phase G called `/pr-cycle`
    recursively for the PROJECT_LOG mini-PR, which would itself
    trigger another Phase G → infinite recursion. Added a
    termination rule: if branch starts with `docs/project-log-pr`,
    skip Phase G (`9ddf87f`).
  - automated review (Should Have): restore-test-n8n step 1 looked
    for archives under `~/backups/n8n` only, but the script default
    is `/var/backups/n8n`. Now does multi-location detection:
    `BACKUP_DIR` env override → `~/backups/n8n` → `/var/backups/n8n`
    fallback (`9ddf87f`).
  - automated review (Should Have, 6×): 5 occurrences of
    `pr-workflow`/`infra-patterns` referred to as a "rule" but each
    lives under `.claude/skills/`; renamed all to "skill". Pattern
    Y wording in `new-service` Q&A item 2 contradicted the compose
    template (bind mount vs named volume); reworded to scope
    Pattern Y to `archive`/`media`/`backup` services only. Disk
    space prereq in `restore-test-n8n` widened from `~5 MB` to
    `~5-50 MB` per `services/n8n/BACKUP.md`. All in `41959fc`.
  - automated review (Disagree): `Copilot` /
    `copilot-pull-request-reviewer[bot]` references in pr-cycle were
    flagged as AI-attribution violations, but they are literal
    `user.login` values queried via the GitHub API for review
    automation, not authorship attributions. Extended the
    `security-invariants` exception list to include `.claude/skills/`
    (Category B agent instructions, same rationale as the existing
    `.claude/rules/` exception) to make this functional carve-out
    explicit (`41959fc`).
- **Closes**: #87
- **Merge**: `f29bb14`

## 2026-05-20

### PR #94 merged: bind-mount n8n volume to /mnt/appdata/n8n

- **What**: Migrate the n8n data directory from the SD-card Docker
  named volume (`bb-homelab-n8n-data`) to a host bind-mount on the HDD
  at `/mnt/appdata/n8n`, per Pattern Y for `appdata` services. The
  migration had been started on 2026-05-14 and stalled mid-way: the
  n8n container was removed (`docker compose down`) and data copied to
  `/mnt/appdata/n8n` (uid 1000), but the compose was never repointed —
  leaving n8n offline ~6 days with daily backup-cron failures. This PR
  completed it forward: repointed the compose, brought n8n back online
  (healthy, Impropedia workflow present, healthz 200), confirmed
  backups resume. The `bb-homelab-proxy` external network had to be
  created on the Pi — it was absent (Caddy, its usual creator, is not
  yet deployed; the compose declares it `external`).
- **Why**: MVP CORE done-criterion #5 (epic #66). The HDD is the
  durable tier; the SD-card named volume was fragile and invisible in
  `df`. The bind-mount makes the data explicit, on the HDD, and
  trivially backed up.
- **Review**:
  - automated review (Must Have): a default bind-mount auto-creates
    the source on the root filesystem when `/mnt/appdata` is not
    mounted (HDD uses `nofail`), so a failed mount — including on
    reboot auto-restart — would silently start n8n on an empty SQLite
    DB. Switched to long-form bind with `create_host_path: false` so
    the container fails to start instead; verified on the Pi
    (`ba55070`).
  - automated review (Should Have): compose comment hardcoded block
    device `/dev/sda1`, but fstab mounts by UUID and the node can
    change across boots. Replaced with HDD + UUID-mount reference
    (`2887f55`).
  - automated review (Should Have): documented the fresh-host
    prerequisite (`mkdir -p` + `chown 1000:1000`) in README, pointing
    to BACKUP.md (`2887f55`).
- **Pending**: orphan SD volume `bb-homelab-n8n-data` left intact for
  rollback; delete after a 7-day grace period (~2026-05-27) pending
  continued green operation.
- **Closes**: #93
- **Merge**: `abdee00`

### PR #97 merged: deploy Caddy on the Pi + bind-mount data to HDD

- **What**: Deploy the Caddy reverse proxy on the Pi (configured in #14
  / PR #72 but never run) and move its data to the HDD. Caddy now
  terminates HTTPS for `n8n.bb-homelab.local` via its internal CA and
  routes to the n8n container over the shared `bb-homelab-proxy`
  network. Verified live: container up binding 80/443, internal CA root
  generated under `/mnt/appdata/caddy/data`,
  `https://n8n.bb-homelab.local/healthz` → HTTP 200 through Caddy, and
  HTTP 200 with no `-k` from the laptop after installing the CA
  system-wide + the `/etc/hosts` entry. Completes MVP CORE
  done-criterion #7 (epic #66).
- **Why**: single HTTPS entry point for tailnet traffic to every
  backend service; prerequisite for the monitoring stack and
  brasse-bouillon / Postgres. Caddy data (internal CA root) on the HDD
  for the same durability reason as n8n (#93).
- **Review**:
  - automated review (Should Have): named→bind switch has no migration
    path, so a host that already ran Caddy would orphan its data and
    regenerate a CA. Verified moot here (this Pi never ran the
    named-volume layout); added a README migration note for the
    already-deployed case, e.g. future VPS migration #30 (`a290d21`).
  - automated review (Should Have, 2×): the `create_host_path: false`
    fail-fast claim was overstated (only fails when the source is
    absent, not when a dir was created on the rootfs while unmounted)
    and the bootstrap `mkdir` lacked a mount check. Reworded the claim
    and added a `mountpoint -q /mnt/appdata` guard before `mkdir`
    (`7f9f8bb`). Code-enforced start-time guard deferred — services
    start via `docker compose up`, same decision as #93.
- **Closes**: #96
- **Merge**: `5009e48`

## 2026-05-21

### PR #99 merged: document the /mnt layout convention (Pattern Y)

- **What**: Add `storage/LAYOUT.md` formalising the `/mnt` mount-point
  convention — the four roles (`appdata` / `archive` / `media` /
  `backup`), Pattern Y (one role per disk, no RAID/LVM), the current
  integration state (only `/mnt/appdata` mounted; archive deferred;
  media/backup blocked on #47), the "don't write to an unmounted
  `/mnt/<role>`" invariant, and the fstab UUID + nofail convention.
  Referenced from `storage/README.md` and `ARCHITECTURE.md` Layer 1.
- **Why**: a stable, predictable `/mnt` layout every service, backup
  script, and compose file can reference — avoids dead symlinks, broken
  binds, ad-hoc paths. Written while Pattern Y is fresh from the n8n
  (#93) and Caddy (#96) migrations.
- **Review**:
  - automated review (Should Have): the `/new-service` skill still told
    `appdata` services to use a named Docker volume, contradicting the
    bind-mount convention established by n8n/Caddy and documented in
    LAYOUT.md. Updated the skill so every role bind-mounts under
    `/mnt/<role>/<name>/data` with `create_host_path: false` (`27b8374`).
    Caveat (flagged in review on the log mini-PR): that `data` sub-path
    itself diverged from LAYOUT.md's `/mnt/<role>/<service>/` and from
    n8n's actual layout (no `data` subdir — Caddy uses `data`/`config`).
    The sub-path convention (service dir, mounted directly or via
    subdirs) is unified in a follow-up.
- **Refs**: #49 (docs criteria done; physical mounts blocked by #47)
- **Merge**: `22c4387`

### PR #101 merged: unify new-service sub-path convention

- **What**: Follow-up to the review on #100. The skill alignment in #99
  (`27b8374`) had hardcoded a `/data` subdir, diverging from
  `storage/LAYOUT.md` and from n8n (which mounts the service dir
  directly; only Caddy uses `data`/`config` subdirs). Unify on
  `/mnt/<role>/<service>/` as the per-service directory — mounted
  directly for single-volume services, via subdirs for multi-volume —
  across the `/new-service` skill and LAYOUT.md.
- **Why**: keep the skill, the doc, and the two deployed services (n8n,
  Caddy) describing one convention, so the next service scaffolds right.
- **Review**:
  - automated review (Should Have): the prose shorthand
    `/mnt/appdata/caddy/data + /config` conflated host and container
    paths; spelled out both host subdirs and their container targets
    (`966f70e`).
  - automated review (Should Have, 6×): harmonised the `<service>`
    placeholder to `<name>`; softened the overstated
    `create_host_path: false` "fail-fast" claim (it fails only when the
    source is absent — the real invariant is `mountpoint -q /mnt/<role>`)
    in both the Q&A
    and the compose-template comment; added a Bootstrap note to create
    multi-volume subdirs (`5271c78`, `78e479e`).
- **Refs**: #49
- **Merge**: `c5ac2f1`

## 2026-05-23

### PR #104 merged: UML deliverables for the Jellyfin media center

- **What**: Added the UML deliverables for the media-center feature
  under `docs/architecture/diagrams/jellyfin/` — use-case (viewer vs
  admin goals grouped by domain), sequence (watch-from-projector,
  making the Direct-Play-vs-transcode branch explicit), component
  (three access paths: LAN `:8096` / tailnet / Caddy; Pattern Y
  storage; the no-off-site-egress property).
- **Why**: model-first per the UML-first rule — the diagrams are the
  contract the deployment must satisfy. Modelled here in parallel with
  the build; going forward conception precedes code.
- **Notes**: `class`/`state`/`data-flow` intentionally omitted (no new
  domain types, no critical state machine, no outbound PII). Branched
  cleanly from `main` in a git worktree to avoid contaminating a
  parallel chantier's uncommitted work in the shared tree.
- **Refs**: #12
- **Merge**: `e89d0fa`

### PR #103 merged: deploy Jellyfin media server

- **What**: Scaffolded the Jellyfin service (`services/jellyfin/`) —
  pinned image `10.11.9` (multi-arch → arm64 on the Pi),
  `config`/`cache`/`media` bind-mounts on the `appdata` role
  (Pattern Y), port `8096` published for direct tailnet/LAN access,
  shared `bb-homelab-proxy` network, `/health` healthcheck. Added
  ADR 0003 (Jellyfin over Plex/Emby via a weighted decision matrix +
  Direct-Play-first strategy for the Pi 5), the Caddy route
  `jellyfin.bb-homelab.local`, and the service-index status.
- **Why**: the media center is the P2 service after n8n (issue #12);
  Jellyfin chosen for its all-open-source, no-account, no-cloud fit with
  the tailnet-only homelab (decision #28).
- **Decision**: the media library lives temporarily on the `appdata`
  disk (read-only) because the media disk (Disque B, `/mnt/media`) is
  not mounted yet (#47); migration path documented in ADR 0003.
- **Review**: no automated review posted — the configured reviewer
  could not be added via API (422, not a collaborator); waived per
  CONTRIBUTING's non-blocking-review rule for a solo developer. CI was
  green (5/5 required + Sonar) and `mergeStateStatus` CLEAN; #103 was
  re-synced with `main` (strict mode) after #104 merged, then squash-
  merged.
- **Closes**: #12
- **Merge**: `1bc321e`

## 2026-05-24

### PR #106 merged: deploy Uptime Kuma + monitoring architecture (Stack B, part 1)

- **What**: Deployed Uptime Kuma (`services/uptime-kuma/` — pinned
  `2.3.2`, HDD bind-mount Pattern Y, healthcheck), the Caddy route
  `status.bb-homelab.local`, and captured the monitoring architecture in
  **ADR 0004** (layered: active Uptime Kuma for service-down + external
  Healthchecks.io dead-man's-switch for Pi-dead / WAN-down + planned
  Pi 3 cross-watch; single fault-only Telegram channel) with UML
  component + data-flow diagrams. A dedicated Telegram bot was wired into
  Kuma (n8n + Caddy monitors); a real DOWN→alert was validated
  end-to-end.
- **Why**: a multi-service homelab needs proactive alerting; ADR 0004
  maps each need (Pi-dead / service-down / WAN-down) to the monitoring
  paradigm that can actually satisfy it (issue #44).
- **Scope**: Beszel (originally bundled in #44) was **dropped** per
  ADR 0004 in favour of an external Healthchecks.io dead-man's-switch
  (Phase 2). This PR delivers the Uptime Kuma half.
- **Review**: automated review posted 3 comments. Two addressed
  (`1505c1b`): a stale "ADR 0003 reserved/not-yet-written" note (0003
  exists post-rebase) and the data-flow edge direction (Uptime Kuma
  probes actively, so `Kuma → services`). One **Disagree**: the French
  `services/uptime-kuma/README.md` is intentional per docs-conventions
  §Category A (which overrides AGENTS.md's general English rule); a real
  AGENTS.md-vs-docs-conventions inconsistency was flagged for a separate
  cleanup.
- **Incident**: Uptime Kuma was first deployed from the unmerged
  `feat/44`; the Pi's checkout of `main` (for the Jellyfin deploy)
  reverted the Caddyfile and dropped the `status` route (TLS error on
  `status.bb-homelab.local`). Restored via a temporary local Caddyfile
  edit, then made permanent by this merge + `git pull` on the Pi. Lesson:
  do not leave a deployed service relying on an unmerged branch.
- **Refs**: #44
- **Merge**: `d90a8d6`

## 2026-05-25

### PR #108 merged: detail the Jellyfin add-content procedure

- **What**: Expanded `services/jellyfin/README.md` with a full "Ajouter
  du contenu" procedure — films/series tree, one-time split of the two
  libraries (Movies → `/media/films`, Séries → `/media/series`, so the
  scanner does not mix them), naming rules (`Titre (Année)`, `SxxEyy`,
  sidecar subtitles), server-side deposit (SFTP via the file manager or
  `scp`; the web UI does not upload), then scan + Identify for mismatches.
- **Why**: clarify the mental model — Jellyfin reads files already in the
  media folder and auto-fetches metadata from a correctly-named file —
  so content can be added autonomously without guesswork.
- **Review**: automated review posted 3 comments, all addressed
  (`9dc6e84`) + replied inline. `automated review (Should Have)`: the
  hardcoded LAN IP was replaced with `http://bb-homelab:8096` (consistent
  with the bootstrap section, no DHCP fragility). `automated review
  (Should Have)`: a permissions inconsistency — the bootstrap creates
  `media/` via `sudo mkdir` (root-owned), so SFTP/scp as `benoit` would
  fail; added an explicit `chown` step and pointed the upload note to it.
  `automated review (Should Have)`: the default series metadata provider
  is TheMovieDb (not TheTVDB, which is optional) — reworded accordingly.
- **Refs**: #12
- **Merge**: `47a34e3`

### Jellyfin went live on the Pi

- **What**: Deployed Jellyfin on the Pi from the #103 recipe — container
  `healthy`, port `8096` reachable on the LAN (`192.168.1.216`, DHCP) and
  the tailnet; first-run wizard completed (admin account, one initial
  Movies library on `/media`); a Creative Commons test file was indexed
  with auto-fetched metadata, validating the end-to-end pipeline.
- **Libraries**: at go-live a single Movies library pointed at `/media`
  (the file sat in `/media/films`, found by the recursive scan). The
  two-library split (Movies → `/media/films`, Séries → `/media/series`)
  is the documented #108 setup, to apply when series are added.
- **Operational note**: `/mnt/appdata/jellyfin/media` was `chown`-ed to
  `benoit` so files can be dropped over SFTP/scp without `sudo` (the #103
  bootstrap created it root-owned). This step is now reflected in the
  README procedure (#108).
- **Pending**: TV client login on the projector via Quick Connect (the
  IR remote makes password entry impractical) — deferred.
- **Refs**: #12

## 2026-06-04

### PR #111 merged: scaffold the Vaultwarden service (password vault)

- **What**: Scaffolded `services/vaultwarden/` (Bitwarden-compatible,
  self-hosted password vault) on the existing homelab layers — pinned
  image `vaultwarden/server:1.36.0`, no host port (Caddy reaches it as
  `vaultwarden:80` on `bb-homelab-proxy`), bind-mount
  `/mnt/appdata/vaultwarden` → `/data` with `create_host_path: false`,
  Argon2 `ADMIN_TOKEN` with fail-fast, `/healthcheck.sh` healthcheck,
  consistent-snapshot `backup.sh`, a tailnet-only Caddy route
  (`vaultwarden.bb-homelab.local`, `tls internal`), `README` + `BACKUP`,
  and ADR 0005.
- **Why**: a private, self-hosted password vault reachable from the
  Bitwarden apps, with nothing in a third-party cloud.
- **Decision (ADR 0005)**: Vaultwarden over HashiCorp Vault (the right
  tool for human password management, light on the Pi, consistent with
  the `bw`-based secret conventions); tailnet-only (decision #28);
  internal CA (ADR 0002); **install now but NOT a Tier-0 dependency**
  until a unified off-site backup, a restore drill, the Uptime Kuma probe
  and the dead-man's-switch are green (#19) — a break-glass copy stays
  off-Pi until then.
- **Review**: automated review posted 9 comments across two rounds, all
  addressed (`b118c0c`, `836f60e`, `2bd60da`) + replied inline.
  `automated review (Must Have)`: `SIGNUPS_DOMAINS_WHITELIST` overrides
  `SIGNUPS_ALLOWED=false`, so the bootstrap "close" step now requires the
  whitelist to stay empty. `automated review (Should Have)`: the backup DB
  snapshot is taken before the attachment/send blobs are copied (no
  DB-vs-blob race). `automated review (Should Have)`: `KEEP=0` now disables
  rotation instead of wiping every archive, including the one just written.
  `automated review (Should Have)`: the README status was reworded as
  scaffold, not "installed and usable". `automated review (Should Have)`:
  the admin-hash command was pinned to `vaultwarden/server:1.36.0`.
  `automated review (Should Have)`: `BACKUP.md` documents the
  sqlite3-absent pause fallback.
- **Language (to correct)**: per `.claude/rules/docs-conventions.md`
  (which takes precedence over AGENTS.md), Category-A human-facing docs —
  `services/*/README.md` and ADRs — are **French**. During review the
  service docs were switched to English on an AGENTS.md §4 reading that
  misses this authoritative rule; the `README` and ADR 0005 language is to
  be corrected to French in a follow-up. `PROJECT_LOG.md` itself is
  Category C (English), so this entry stays English.
- **Scope**: repo scaffold only — the live deploy on the Pi follows; #25
  stays open until go-live.
- **Refs**: #25
- **Merge**: `ae463ab`

### PR #113 merged: correct README + ADR 0005 to French

- **What**: Switched `services/vaultwarden/README.md` and ADR 0005 from
  English to French, per `.claude/rules/docs-conventions.md` (Category-A
  human-facing docs are French; that rule takes precedence over
  AGENTS.md). Closes the "Language (to correct)" follow-up flagged in the
  PR #111 entry above.
- **Refs**: #25
- **Merge**: `ab56d7a`

### Vaultwarden went live on the Pi

- **What**: Deployed Vaultwarden on the Pi from the merged scaffold — the
  container is `healthy` and reachable only through Caddy over HTTPS
  (`vaultwarden.bb-homelab.local`, `/alive` → 200, no host port). The
  single account was created through a one-time signup window (set
  `SIGNUPS_ALLOWED=true`, registered, then back to `false`; the domain
  whitelist was kept empty so it cannot override the close). The Argon2
  admin token and the account master password live only in an external
  password manager (break-glass) — never on the Pi.
- **Backup**: first consistent snapshot taken via the pause + `docker cp`
  fallback (sqlite3 is absent from the stock image; the container resumed
  cleanly), archive `chmod 600` containing `db.sqlite3` + `rsa_key.pem`.
  A daily 03:05 user cron now runs `backup.sh` (`KEEP=7`) to
  `~/vaultwarden-backups`. `PRAGMA integrity_check` is deferred to the
  restore drill (no sqlite3 on the host) — a Tier-0 gate item anyway.
- **Incident fixed in passing**: Caddy had been left attached to no
  Docker network after the earlier outage restoration — the container
  was running but orphaned from `bb-homelab-proxy`, so nothing listened
  on host `:80`/`:443` and *every* service was unreachable from clients,
  not just Vaultwarden. Root cause: the restoration `docker restart`-ed
  Caddy instead of recreating it, and `restart` does not re-attach a lost
  network. Fixed with `docker compose up -d --force-recreate`; Uptime
  Kuma sent the `Caddy Up` recovery. n8n and Jellyfin ingress recovered
  with it.
- **Observation**: Caddy serves the web-vault assets uncompressed; over
  the Pi's flaky DERP-relayed 5G uplink (~24 KB/s) the multi-MB web vault
  times out. The lightweight Bitwarden clients (extension/app) are the
  intended daily path; enabling `encode zstd gzip` on Caddy is a cheap
  follow-up that also helps n8n and Jellyfin.
- **Pending**: browser-extension and mobile pairing (deferred — needs the
  internal CA on the client and a usable link); the Uptime Kuma probe on
  `/alive`; off-site backup + restore drill (#19). #25 stays open until
  client pairing is done.
- **Status**: live and usable on the tailnet, but **not Tier-0** (ADR
  0005 gate) — the existing password manager remains the source of truth.
- **Refs**: #25, ADR 0005, #19

## 2026-06-05

### PR #115 merged: Vaultwarden client onboarding guide (CLIENTS.md)

- **What**: Added `services/vaultwarden/CLIENTS.md` — how to pair the
  Bitwarden clients with the self-hosted instance: the master-vs-admin
  password distinction, why the lightweight clients beat the Web Vault on
  the relayed uplink, internal-CA trust + self-hosted server setup, the
  Firefox extension flow (log in, never "Create account" cloud),
  desktop/CLI, deferred mobile (split-DNS), and troubleshooting.
- **Language**: English, consistent with its sibling `BACKUP.md`. Per
  `.claude/rules/docs-conventions.md`, Category-A French covers
  `services/*/README.md` and ADRs — not the other operational service
  docs, which stay English.
- **Review**: automated review posted 7 comments across two rounds, all
  addressed (`a0d185d`) and replied inline; the re-review returned no
  further comments. `automated review (Should Have)`: the master-password
  wording was corrected — the raw password never leaves the device, but a
  derived authentication hash does. `automated review (Should Have)`: the
  mobile rationale was corrected — Caddy does publish `:443`, so the
  blocker is hostname resolution + TLS match, not missing host ports.
  `automated review (Should Have)`: the CA filename (`bb-homelab-root.crt`)
  and the SSH host alias (`benoit@bb-homelab`) were aligned with
  `services/caddy/README.md`.
- **Refs**: #25 — the browser-extension acceptance criterion is now met in
  practice; mobile pairing remains, so #25 stays open.
- **Merge**: `169512c`

### Vaultwarden clients paired, monitored, and backup-verified

- **What**: Onboarded the Firefox extension end to end — imported the
  Caddy internal CA into Firefox's own store, pointed the extension at the
  self-hosted server (`https://vaultwarden.bb-homelab.local`), and logged
  in with the master password (not a cloud account). The browser-extension
  acceptance criterion of #25 is now met in practice.
- **Monitoring**: registered the Uptime Kuma probe on
  `http://vaultwarden:80/alive` (plain HTTP over `bb-homelab-proxy`,
  accepted status 200-299, 60 s interval, `BB Infra Alerts` Telegram
  notification attached). Verified `Up`, `200 - OK`, ~3 ms response. This
  closes Tier-0 gate criterion 3.
- **Backup verification**: ran the non-destructive *"verifying an archive
  is restorable"* check from `BACKUP.md` — extracted the latest archive to
  `/tmp`, `PRAGMA integrity_check` → `ok`, expected rows present (1 user,
  1 device, `rsa_key.pem`), then cleaned up (`sqlite3` is absent from the
  host, so the check ran via `python3`). A manual `backup.sh` then captured
  the first vault item and re-verified (`ciphers: 1`, integrity `ok`).
  This is **not** the full Tier-0 restore drill: `BACKUP.md` defines that
  as `extract → integrity_check → bring up a throwaway instance → log in`,
  and the throwaway-instance + login step has not been run — so criterion 2
  stays open.
- **Tier-0 gate**: 1/4 — only criterion 3 (Uptime Kuma probe) is green.
  Criterion 2 (restore drill) is partially advanced (archive integrity
  verified; the throwaway-instance + login step remains). Remaining:
  criterion 1 (unified off-site backup, #19), criterion 2's full drill,
  and criterion 4 (Healthchecks.io dead-man's-switch — confirmed not yet
  wired, no `hc-ping` in the backup path).
- **Status**: live, monitored, and usable on the tailnet via the Firefox
  extension — still **not Tier-0** (ADR 0005 gate). The existing password
  manager stays the source of truth.
- **Refs**: #25, ADR 0005, ADR 0004, #19

## 2026-06-16

### PR #118 merged: Docker healthcheck for Caddy

- **What**: Added a healthcheck to the Caddy service
  (`services/caddy/docker-compose.yml`) — probes a new plain-HTTP
  `/healthz` route (a `localhost`-only site in the Caddyfile) every 30 s
  (timeout 5 s, 5 retries, `start_period` 10 s). Caddy was the last
  homelab service without a liveness probe, despite being the frontal
  reverse proxy (80/443) for every tailnet-facing service.
- **Why**: a dead/wedged proxy now surfaces in `docker ps` and to Uptime
  Kuma. Chose a dedicated `/healthz` route over the admin API —
  deterministic, tests the port-80 data plane, independent of the admin
  endpoint. No `depends_on` to the backends (separate compose projects on
  the external `bb-homelab-proxy` network; `depends_on` does not cross
  projects).
- **Also**: corrected `services/caddy/README.md` Security notes, which
  wrongly claimed *"Admin API disabled (`admin off`)"* — the admin API
  listens on `localhost:2019` (required by `caddy reload`).
- **Verification**: `caddy validate` plus a throwaway-container run proved
  `/healthz` returns 200, the probe command exits 0 (`wget` is the BusyBox
  applet shipped in the Alpine image), and the existing
  `*.bb-homelab.local` HTTP→HTTPS redirects still work. Pi verification
  (`docker compose up -d` → `healthy`) pending a maintenance window.
- **Review**: `automated review (Disagree)`: a reviewer flagged `wget` as
  missing from `caddy:2.8.4`; refuted inline with proof it is the BusyBox
  `wget` applet (`/usr/bin/wget` → `/bin/busybox`), same probe family as
  n8n's healthcheck.
- **Scope**: Caddy only; `start_period` for n8n + uptime-kuma deferred to
  a follow-up.
- **Refs**: #117
- **Merge**: squash-merged.

### Repository flipped to public visibility

- **What**: Changed `bb-homelab` from private to public
  (`gh repo edit --visibility public`). Trigger was a GitHub Actions
  billing hold (failed payment / spending limit) that blocked CI on PR
  #118; public repos get unlimited free Actions.
- **Public Release Checklist**: ran the full gate before flipping —
  `gitleaks detect` on full history (73 commits) returned **0 leaks**; no
  secrets / certs / keys / tokens / bot-tokens in any tracked file; only
  `.env.example` files ever tracked (no real `.env` in history); gitleaks
  CI present. All five items satisfied.
- **Residual disclosure (accepted)**: non-routable IPs remain in tracked
  files and history — the tailnet IP (CGNAT `100.64.0.0/10`, reachable
  only from the tailnet) and LAN IPs (`192.168.1.x`, RFC1918). A
  forward-only scrub was rejected as cosmetic (history retains them) and a
  history rewrite as disproportionate for non-routable addresses.
- **Free alternatives considered**: resolving the billing hold (private
  repos include 2 000 free Actions min/month) and a self-hosted runner —
  both keep the repo private; the maintainer chose public.
- **Follow-up**: invariant docs synced to public visibility (PR #119);
  reverting to private remains possible (`gh repo edit --visibility
  private`) but does not un-expose already-public history.
- **Refs**: #118, #119
