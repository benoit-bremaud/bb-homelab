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
  - codex (Must Have): added `-a` to `docker cp` to preserve UID/GID.
  - Copilot (Must Have): `cleanup()` now verifies unpause succeeded
    via `docker inspect .State.Paused` before running `docker exec rm`
    — otherwise the trap would deadlock if unpause failed.
  - Copilot (Should Have): added host-side `tar` preflight so the
    script fails fast before touching the container.
  - Copilot (Should Have): corrected "SIGSTOP via docker pause"
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
  - Copilot (Should Have): two comments on workflow trigger filter
    inconsistency, addressed in `707630e`.
  - Copilot (Re-review): post-`cd11693` review flagged no further
    issues.
- **Token rotation incident**: a token was briefly exposed in a setup
  screenshot, immediately revoked and regenerated before use. Lesson:
  copy secrets straight from password manager into the destination
  form, never via an intermediate visible buffer.
- **Closes**: #61
- **Merge**: `90b0fbc`
