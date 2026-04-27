# ADR 0002 — Caddy as the internal reverse proxy

- **Status**: Accepted
- **Date**: 2026-04-27

## Context

bb-homelab is moving from one service (n8n) to a multi-service homelab
(Jellyfin, monitoring, brasse-bouillon, etc., per epic #66). Without a
reverse proxy, every service exposes its own port on the host (`:5678`,
`:8096`, `:3001`, …) and clients need to remember an IP-and-port pair
per service. That pattern collapses past 2-3 services and gives no
place to attach HTTPS, auth, or rate limiting.

A reverse proxy provides one entry point per public port (80/443),
host-based routing, and a natural seam for TLS termination. It is also
the natural pre-requisite for layering authentication or forward-auth
on shared services later.

The repo already has cloudflared in front of n8n for **public**
webhooks (Impropedia widget). That path is healthy and unchanged. This
ADR concerns **internal tailnet traffic** only.

## Decision

Adopt Caddy 2.x as the internal reverse proxy for tailnet-facing
traffic, with the following four sub-decisions:

1. **Caddy over nginx / Traefik.** Caddy ships with batteries included:
   automatic HTTPS, automatic certificate management (internal CA
   today, Let's Encrypt tomorrow), one-line route blocks. We don't
   need the granularity of nginx and we want to avoid Traefik's
   coupling to Docker labels.
2. **Shared external Docker network `bb-homelab-proxy`.** Created once
   on the host (`docker network create bb-homelab-proxy`). Every
   backend service joins it via `external: true` in its own
   `docker-compose.yml`. Caddy and backends can be torn down /
   upgraded independently without losing the bridge.
3. **TLS via Caddy's internal CA (`tls internal`) — phase 1.** No
   public domain is owned yet (decision #28 deferred). Caddy
   auto-generates a local root CA on first start; the root cert is
   installed once on each client device. When a domain arrives,
   `tls internal` is removed, ACME takes over, and the local root CA
   can be uninstalled from clients.
4. **Hostnames `*.bb-homelab.local` resolved via client `/etc/hosts`
   pointing at the Pi's Tailscale IP.** Independent of any name
   service, works on every device, no Tailscale MagicDNS coupling.

cloudflared stays in its current configuration: webhooks continue to
flow `cloudflared → n8n:5678` directly. The two paths (public-via-
cloudflared, internal-via-Caddy) are deliberately decoupled so an
outage on one cannot take the other down.

## Consequences

**Positive:**

- Adding a service is an entry in the Caddyfile + the service joining
  `bb-homelab-proxy`. No host-level config touched.
- HTTPS everywhere on the tailnet from day one — green padlock once
  the root CA is installed on a client.
- Migration to a public domain (phase 2) is local: replace
  `tls internal` with the ACME default and rename hostnames; nothing
  else changes.

**Negative:**

- Each new client device must install the Caddy root CA once. With a
  small set of devices (laptop + phone + family laptops) this is
  acceptable; it would not scale to a public site.
- Caddy and the backends share a Docker network — a misconfiguration
  in one service can in theory be reached by Caddy. Mitigated by
  per-service compose isolation and Caddy listening only on
  Tailscale-exposed ports (UFW restricts inbound from outside
  `tailscale0`).
- `*.bb-homelab.local` requires manual `/etc/hosts` lines on each
  device. Acceptable for a small, mostly-static set of services.

## Alternatives considered

- **Tailscale MagicDNS + Tailscale-issued HTTPS certs.** Cleaner long
  term (no root CA install) but couples internal access to
  Tailscale's name service and HTTPS subsystem. Rejected for phase 1
  to keep the proxy layer agnostic; can be revisited as a phase-2
  variant alongside Let's Encrypt.
- **All-cloudflared (named tunnel for every service).** Blocked by
  decision #28 (no domain bought yet) and would expose every service
  publicly by default — a security posture we don't want for internal
  tools.
- **No proxy, document each port on the wiki.** Rejected: doesn't
  scale, no HTTPS, no future seam for auth.
- **Host-level Caddy as a systemd service (no container).** Rejected:
  diverges from the project's "everything in Docker" pattern set by
  ADR 0001 layer 5 (application packaging via Docker images).

## Refs

- Issue #14 — infra(services): deploy Caddy reverse proxy with
  auto-HTTPS
- Decision #28 — domain purchase (deferred)
- ADR 0001 — DIP layering (this ADR fits layer 2: Network / access)
- `services/caddy/` — implementation (Caddyfile, docker-compose,
  README)
