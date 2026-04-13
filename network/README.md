# network/ — Layer 2 (Network / access)

Everything that controls how traffic enters and leaves the homelab:
remote access for the admin (you), private access for the circle of
trust (family, theatre troupe), and public webhooks for services that
need to be reachable from the internet (e.g. the impropedia widget).

## Components planned

- **Tailscale** — mesh VPN for admin SSH and private service access.
  Free, no domain required. Install procedure + script:
  [tailscale.md](tailscale.md) / [install-tailscale.sh](install-tailscale.sh).
- **cloudflared** — Cloudflare tunnel exposing public webhooks. Today
  ephemeral (`*.trycloudflare.com`), upgradable to a named tunnel once
  a domain is purchased (decision **#28**).
- **Reverse proxy (Caddy)** — single entry point routing host-based
  subdomains to the right service container, with auto-HTTPS. Tracked
  as **issue #14**.

## Boundaries between components

| What | Tool | Why |
|---|---|---|
| Admin SSH from anywhere | Tailscale | Encrypted, no port forwarding, no public IP exposure |
| Family/troupe access to private UIs | Tailscale | Free, app install on their device, zero config on the router |
| Public webhooks (widget → n8n) | cloudflared | The widget runs in browsers we don't control; needs a public URL |
| Internal routing between services | Caddy + Docker network | Centralises TLS and host-based routing |

## Until the configs land

Network setup procedures are tracked across multiple issues — see #5
(Tailscale), #14 (Caddy), and #28 (domain decision).
