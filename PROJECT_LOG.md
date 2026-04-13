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
