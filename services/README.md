# services/ — Layers 4-6 (Orchestration + Packaging + Service)

One folder per service stack. Each folder is self-contained:
`docker-compose.yml`, `.env.example`, a service-specific `README.md`,
optional `BACKUP.md` for stateful services.

The convention: a service's folder must be **runnable in isolation**.
You should be able to `cd services/<name> && docker compose up -d`
without depending on anything outside that folder, except shared
infrastructure (reverse proxy, Tailscale) which is bootstrapped first.

## Planned services

| Service | Folder | Tracked in | Status |
|---|---|---|---|
| n8n + cloudflared | `n8n/` | issue #6, #7, #8 | Files migrated from `impropedia-infra` (#6); volume migration PC → Pi pending (#7) |
| Caddy reverse proxy | `caddy/` | issue #14 | Planned |
| Jellyfin (media) | `jellyfin/` | issue #12 | Stopped 2026-11-05, replaced by PopCornTV; removed two weeks after cut-over |
| PopCornTV (media) | `popcorntv/` | issue #240 | Live compose; library on `/mnt/appdata/media` until `/mnt/media` (#47) |
| Immich (screenshots) | `immich/` | issue #224 | Compose ready; Pi deploy waits for fixed upstream images (ADR 0010) |
| PostgreSQL | `postgres/` | issue #17 | Planned |
| brasse-bouillon backend | `brasse-bouillon/` | issue #15 | Planned |
| brasse-bouillon frontend | `brasse-bouillon/` | issue #16 | Planned |
| Uptime Kuma | `uptime-kuma/` | issue #20 | Planned |
| Watchtower | `watchtower/` | issue #22 | Planned |
| Pi-hole | `pihole/` | issue #24 | Nice-to-have |
| Vaultwarden | `vaultwarden/` | issue #25 | Scaffolded — install pending; NOT Tier-0 until backup proven (#19) |
| Home Assistant | `home-assistant/` | issue #26 | Nice-to-have |

## Per-service folder conventions

```text
services/<name>/
├── docker-compose.yml
├── .env.example          # all required env vars, placeholder values
├── README.md             # what this service does + how to deploy/use
└── BACKUP.md             # only if the service has persistent state
```

`.env` is gitignored (real secrets live there). `.env.example` is the
documented contract.
