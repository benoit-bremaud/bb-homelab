# Architecture

The repo is organised around a single principle borrowed from CLEAN/SOLID
code: **the Dependency Inversion Principle (DIP), applied to infrastructure**.

In code, DIP means business logic depends on abstractions, never on concrete
adapters (databases, frameworks, transports). In infrastructure, the same
principle splits the system into layers that depend only on the abstractions
of the layer below them, never on the concrete implementation.

If we ever swap the Raspberry Pi for a mini-PC, or Docker Compose for
Kubernetes, or the ephemeral cloudflared tunnel for a named one, **only the
layer being swapped should change**. Every layer above it stays untouched.

## The six layers

| # | Layer | Role | Today on this homelab | Could become tomorrow |
|---|---|---|---|---|
| 6 | **Service** | Business logic — the thing users actually use | n8n workflows, Jellyfin, Vaultwarden | Identical (the invariant) |
| 5 | **Application packaging** | How a service is bundled to run anywhere | OCI / Docker images | Same Docker images, or Podman |
| 4 | **Orchestration** | How multiple services boot, restart, share networks/volumes | `docker compose` | Kubernetes, Nomad, Podman quadlets |
| 3 | **Host / OS** | The machine + its operating system | Raspberry Pi 5 + Raspberry Pi OS Lite 64-bit | Mini-PC + Debian, Hetzner CAX VPS, Synology |
| 2 | **Network / access** | How the world reaches a service | cloudflared (ephemeral) + Tailscale | Cloudflared named tunnel, WireGuard, reverse proxy with HTTPS |
| 1 | **Storage** | Where data lives | Docker volume on SD card | USB SSD, mounted external HDDs, NAS, S3 |

Higher layers (top of the table) are the parts that carry user value and
should rarely change. Lower layers are operational concerns that we expect
to evolve as scale, budget, or hardware change.

## Repo layout reflects the layers

```text
bb-homelab/
├── README.md                       # entry point
├── ARCHITECTURE.md                 # this file
├── PROJECT_LOG.md                  # chronological logbook
├── CONTRIBUTING.md                 # conventions
│
├── bootstrap/                      # Layer 3 — Host / OS
│   └── (idempotent setup of a fresh Pi)
│
├── network/                        # Layer 2 — Network / access
│   └── (Tailscale, cloudflared, reverse proxy configs)
│
├── services/                       # Layers 4-6 — Orchestration + Packaging + Service
│   ├── n8n/                        #   one folder per docker-compose stack
│   ├── jellyfin/
│   └── ...
│
├── storage/                        # Layer 1 — Storage
│   ├── LAYOUT.md                    #   /mnt convention (Pattern Y, roles)
│   └── (HDD mount procedures, SMART scripts, backup scripts)
│
└── docs/
    └── decisions/                  # ADRs (Architectural Decision Records)
        └── 0001-dip-layering.md
```

## Walkthrough — what happens when a feedback POST hits a widget

To make the layering tangible, here is the path of a single HTTP POST from
the impropedia widget to the Telegram message a proofreader receives:

| # | Layer touched | What happens |
|---|---|---|
| 1 | **Storage** (none yet) | — |
| 2 | **Network** | The request enters via the cloudflared tunnel running on the Pi (`network_mode: host`) and is forwarded to `http://127.0.0.1:5678/webhook/feedback`. |
| 3 | **Host / OS** | The Linux kernel routes the packet to the n8n container's port. |
| 4 | **Orchestration** | Docker compose keeps the n8n container alive; restart policy `unless-stopped` covers crashes. |
| 5 | **Packaging** | The official `n8nio/n8n` Docker image starts the Node process at boot. |
| 6 | **Service** | The n8n workflow `Webhook → Telegram` runs: it reads the JSON body, formats the Telegram message, calls the Telegram Bot API. |

If we replace the Pi with a mini-PC tomorrow (layer 3), only the bootstrap
script and SSH inventory change. If we move from cloudflared ephemeral to a
named tunnel (layer 2), only `network/` and a single line in `docker-compose.yml`
change. The n8n workflow JSON is untouched in both cases.

## Decisions

Every architectural choice that has more than one defensible answer is
recorded as an ADR (Architectural Decision Record) under
[docs/decisions/](docs/decisions/). The first one is `0001-dip-layering.md`,
which formalises the choice described in this file.
