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

## Exposition réelle par port (#139)

Les ports publiés par Docker contournent UFW (ADR 0007) : seule leur
adresse de liaison décide qui les joint. Relevé du 2026-11-02.

| Port | Service | Liaison | Joignable depuis |
|---|---|---|---|
| 22/tcp | SSH (hôte) | toutes | LAN + tailnet (UFW `ALLOW Anywhere`, R13) ; le portable de la maison y tire la copie d'Immich par le LAN (`rrsync -ro`, ADR 0010) |
| 80, 443/tcp, 443/udp | Caddy | `127.0.0.1` + IP tailnet | Pi + tailnet |
| 8096/tcp | Jellyfin | `127.0.0.1` + IP tailnet | Pi + tailnet |
| 2283/tcp | Immich | `127.0.0.1` + IP tailnet | Pi + tailnet (app mobile, ADR 0010) |
| 5678/tcp | n8n | `127.0.0.1` | Pi (Internet via le tunnel cloudflared) |
| 8123/tcp | Home Assistant (hôte) | toutes | tailnet, Nest Mini (UFW, #162) |
| 1883/tcp | Mosquitto (dépôt `home-assistant`) | toutes | LAN + tailnet, voulu pour les ESP32 |
| 8080, 10200, 10300 | Z2M, piper, whisper (dépôt `home-assistant`) | `127.0.0.1` | Pi |

Contrôle : `docker ps --format '{{.Names}} {{.Ports}}'` et `ss -tlnp`
sur le Pi ; depuis un hôte du LAN hors tailnet, `curl -m 5
http://192.168.1.216:8096` doit échouer.

## Until the configs land

Network setup procedures are tracked across multiple issues — see #5
(Tailscale), #14 (Caddy), and #28 (domain decision).
