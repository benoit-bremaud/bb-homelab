# ADR 0001 — DIP layering applied to infrastructure

- **Status**: Accepted
- **Date**: 2026-04-13

## Context

The repo will host multiple services (n8n, Jellyfin, brasse-bouillon
backend/frontend, possibly more) on a Raspberry Pi 5 today, with a
realistic chance of moving to bigger hardware (mini-PC, VPS) tomorrow.
Without a deliberate structure, configs and scripts tend to leak
hardware-specific assumptions everywhere, making any future migration
expensive.

We want the same property for our infrastructure that CLEAN/SOLID code
gives us in the application layer: **the parts that carry user value
should not depend on the parts that change frequently for operational
reasons**.

## Decision

Organise the repo around six explicit layers, with strict dependencies
flowing top-down:

```text
6. Service              (the thing users actually use)
5. Application packaging (OCI / Docker images)
4. Orchestration         (docker compose today)
3. Host / OS             (RPi + Raspberry Pi OS today)
2. Network / access      (Tailscale + cloudflared today)
1. Storage               (Docker volumes on SD today)
```

Higher layers carry user value and rarely change. Lower layers are
operational concerns and are expected to evolve. Each layer depends only
on the **abstraction** of the layer below, not its current
implementation.

## Consequences

**Positive:**

- Swapping a layer (RPi → VPS, ephemeral tunnel → named tunnel, SQLite →
  PostgreSQL) only touches the corresponding folder. Everything above
  stays untouched.
- The repo layout (`bootstrap/`, `network/`, `services/`, `storage/`)
  mirrors the layers, so finding "the thing that controls X" is
  immediate.
- Each service folder is self-contained and can be moved to a different
  homelab or VPS by copy-paste.

**Negative:**

- Slightly more upfront ceremony (multiple folders, multiple READMEs)
  than a single flat docker-compose file.
- ADRs introduce a documentation overhead — but only for choices that
  have more than one defensible answer.

## Alternatives considered

- **Single `docker-compose.yml` at the repo root with everything.**
  Rejected: any change to one service forces re-reading the entire file,
  and there's no clean separation between "infra" and "service" concerns.
- **One git repo per service, one repo for the host.** Rejected: too
  many small repos, painful to keep their interplay documented and
  in-sync. We keep the single `bb-homelab` repo and use folders to
  separate concerns.
