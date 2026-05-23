# ADR 0003 — Jellyfin as the media server

- **Status**: Accepted
- **Date**: 2026-05-23

## Context

The media center is the second-most-wanted service after n8n
(issue #12, epic #66). The goal: a self-hosted "Netflix" streaming
films, series and music to phones and TVs on the tailnet.

The choice has more than one defensible answer — Jellyfin, Plex and
Emby all do the job — so it warrants an ADR. Two project constraints
weigh heavily on the decision:

- **No public ingress, tailnet-only** (decision #28): the server is
  reached over Tailscale / LAN, never exposed publicly.
- **Privacy-first, no third-party account, free**: consistent with a
  homelab whose point is to own the stack end to end.

A second sub-question is the **media library location**, because the
media disk (Disque B, `/mnt/media`) is not mounted yet (issue #47).

## Decision

### 1. Jellyfin over Plex / Emby

Scored comparison, criteria weighted by the constraints above
(score 1-5 per criterion, weighted sum out of 100):

| Criterion (weight) | Jellyfin | Plex | Emby |
|---|---|---|---|
| Open-source & no mandatory account (25) | 5 | 1 | 2 |
| Fully local / no cloud dependency (20) | 5 | 2 | 4 |
| Cost (15) | 5 | 2 | 3 |
| Pi 5 / ARM64 & transcoding (15) | 3 | 3 | 3 |
| Client apps, TV / mobile (15) | 4 | 5 | 4 |
| Maintenance & community (10) | 4 | 5 | 4 |
| **Weighted score /100** | **89** | **53** | **64** |

Jellyfin wins decisively because the two heaviest criteria
(open-source/no-account and fully-local) are exactly its strengths:
GPL-licensed, no account, no phone-home, zero paywall. Plex is
penalised by mandatory plex.tv authentication (a phone-home path that
conflicts with decision #28) and the growing paywall on remote
playback and hardware transcoding. Emby sits in between — more open
than Plex, but with a partially closed core and an Emby Premiere
paywall for hardware transcoding and apps.

Jellyfin's only real trade-off — partial hardware transcoding on the
Pi 5 — is addressed by sub-decision 3.

### 2. Library on Disque A (appdata), temporarily

Pattern Y places the media library on role `media` (`/mnt/media`,
Disque B). That disk is not mounted yet (issue #47). Rather than block
the whole service, the library lives temporarily on Disque A under
`/mnt/appdata/jellyfin/media`, mounted read-only on the container side.
This is a deliberate, documented, temporary deviation from Pattern Y,
to be reverted when Disque B arrives (see Consequences).

### 3. Direct-Play-first, no reliance on live transcoding

The Pi 5's VideoCore VII GPU does not hardware-transcode every codec.
The supported strategy is Direct Play: store media in formats clients
decode natively (H.264/AAC in MP4/MKV is the safe baseline) rather than
relying on on-the-fly transcoding of high-bitrate 4K HEVC. This keeps
playback smooth within the Pi's envelope and avoids CPU saturation.

## Consequences

**Positive:**

- Fully owned stack: no account, no cloud, no paywall — aligned with
  decision #28 and the privacy-first posture.
- Adding Jellyfin is a standard service folder + one Caddy route,
  exactly like every other service (ADR 0001 layer 5, ADR 0002).
- Direct access on `http://bb-homelab:8096` lets TV/mobile apps connect
  without installing Caddy's internal CA.

**Negative / to revisit:**

- The media library on the `appdata` disk is an explicit Pattern-Y
  deviation. Volume is limited and video I/O shares the fast disk.
  Acceptable for a test library; not for the full collection.
- **Migration when Disque B arrives (issue #47):** mount
  `/mnt/media`, move `/mnt/appdata/jellyfin/media/*` to
  `/mnt/media/jellyfin/` (or the agreed media path), repoint the bind
  source in `docker-compose.yml`, recreate the container, and rescan
  libraries. Track as a follow-up to #12.
- Direct Play shifts the burden to media file formats: poorly-encoded
  sources may not play on every client. Documented in the service
  README.

## Alternatives considered

- **Plex.** Most polished client ecosystem, but mandatory plex.tv
  account and phone-home authentication conflict with decision #28,
  and remote playback / hardware transcoding are paywalled. Rejected.
- **Emby.** More open than Plex and runnable locally, but a partially
  closed core and the Emby Premiere paywall place it behind Jellyfin
  on the weighted criteria. Rejected.
- **Kodi.** A client/HTPC application, not a centralised multi-client
  server. Out of scope for the "stream to phones and TVs from one
  server" goal. Can still be used as a *client* against Jellyfin.
- **Wait for Disque B before deploying anything.** Rejected: blocks a
  wanted service on a hardware delivery; the temporary appdata library
  lets the service run and be validated now, with a clear migration
  path.

## Refs

- Issue #12 — infra(services): deploy Jellyfin container (media library)
- Issue #47 — Disque B + enclosures (unblocks `/mnt/media`)
- Decision #28 — domain purchase deferred (no public ingress)
- ADR 0001 — DIP layering (this ADR fits layer 5: application packaging)
- ADR 0002 — Caddy reverse proxy (the route fronting Jellyfin)
- `services/jellyfin/` — implementation
- `storage/LAYOUT.md` — Pattern Y (`/mnt` layout)
