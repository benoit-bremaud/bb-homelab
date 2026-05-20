# services/caddy — reverse proxy (phase 1)

Caddy is the single entry point for tailnet traffic to every backend
service in the homelab. It terminates HTTPS (with its own internal CA
in phase 1) and routes host-based requests (`n8n.bb-homelab.local`,
future `kuma.bb-homelab.local`, `jellyfin.bb-homelab.local`, …) to
the right container over a shared Docker network.

Public webhooks (Impropedia widget → n8n) continue to travel through
`cloudflared` directly, untouched by this layer. The two paths are
independent by design — see [ADR 0002](../../docs/decisions/0002-caddy-reverse-proxy.md).

## Stack

- **Caddy 2.8.4** (pinned) — HTTPS termination + host-based routing.
- **Shared Docker network `bb-homelab-proxy`** — external, created
  once on the host. Every backend service that Caddy needs to reach
  (n8n, future Kuma / Jellyfin / …) joins this network.
- **Bind-mount `/mnt/appdata/caddy/data`** — persists the internal CA
  root and issued certificates on the HDD (Pattern Y, like n8n). **Must
  survive container restarts** or Caddy regenerates a brand new root CA
  and every client device's trust anchor becomes stale — hence the
  durable HDD rather than the SD card. The compose declares
  `create_host_path: false`, so if the HDD is not mounted Caddy fails
  to start (loud) rather than silently regenerating a CA on the SD card.
- **Bind-mount `/mnt/appdata/caddy/config`** — Caddy's runtime-managed
  state.

## Bootstrap

Pre-requisite: Docker + Compose v2 on the host.

```bash
# 1. Create the shared proxy network (once per host).
docker network create bb-homelab-proxy

# 2. Attach every backend service to that network. For n8n, this
#    is already declared in services/n8n/docker-compose.yml — just
#    re-up the stack:
cd services/n8n && docker compose up -d && cd -

# 3. Create the bind-mount target dirs on the HDD (once per host).
#    Required because the compose uses create_host_path: false.
sudo mkdir -p /mnt/appdata/caddy/data /mnt/appdata/caddy/config

# 4. Start Caddy.
cd services/caddy
cp .env.example .env    # optional; phase 1 runs fine with defaults
docker compose up -d
```

> **Migrating a host that already ran Caddy on named volumes.** The
> bootstrap above assumes a fresh deploy (this Pi never ran the old
> named-volume layout, so there was nothing to migrate). On a host that
> *did* run Caddy from `bb-homelab-caddy-data`, copy the data into the
> bind-mount **before** the first `up`, otherwise Caddy generates a new
> internal CA and every client must re-trust:
>
> ```bash
> sudo mkdir -p /mnt/appdata/caddy/data /mnt/appdata/caddy/config
> sudo cp -a "$(docker volume inspect bb-homelab-caddy-data --format '{{.Mountpoint}}')/." /mnt/appdata/caddy/data/
> sudo cp -a "$(docker volume inspect bb-homelab-caddy-config --format '{{.Mountpoint}}')/." /mnt/appdata/caddy/config/
> ```

Then, on every client device that needs to reach a subdomain:

```bash
# 5. Point *.bb-homelab.local to the Pi's Tailscale IP. On Linux/macOS:
sudo sh -c 'cat >> /etc/hosts <<EOF
100.121.134.61  n8n.bb-homelab.local
# add future routes as services come online
EOF'
```

At this point hitting `https://n8n.bb-homelab.local` works end-to-end,
but the browser will flag the TLS cert as untrusted — Caddy's root CA
is self-signed. Install it (step below) and the warning disappears.

## Install Caddy's root CA on a client

Caddy auto-generates a local root CA on first start. Extract it and
install it on every device that will open a `*.bb-homelab.local` URL.

### Export from the Pi

```bash
# Run on the Pi (ssh benoit@bb-homelab):
docker exec bb-homelab-caddy cat /data/caddy/pki/authorities/local/root.crt > ~/bb-homelab-root.crt

# Copy it to the client device, e.g. your laptop:
scp benoit@bb-homelab:~/bb-homelab-root.crt ~/Downloads/
```

### Install — Linux (system-wide)

```bash
sudo cp ~/Downloads/bb-homelab-root.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
# Firefox: Preferences → Privacy & Security → Certificates → Import → trust for websites
```

### Install — macOS

```bash
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain ~/Downloads/bb-homelab-root.crt
```

### Install — Android / iOS

Transfer `bb-homelab-root.crt` to the device (email, AirDrop, etc.),
tap it, and follow the OS prompt. On Android, newer versions require
installing it under "User certificates" then trusting it manually for
VPN/apps.

### Install — Windows

Double-click the `.crt`, choose "Install Certificate" → "Local Machine"
→ "Place all certificates in the following store" → Browse →
"Trusted Root Certification Authorities".

## Adding a new route

1. Add the backend service to the shared `bb-homelab-proxy` network
   in its own `docker-compose.yml` (see `services/n8n/docker-compose.yml`
   for the pattern).
2. Append a block to `services/caddy/Caddyfile`:

   ```caddyfile
   kuma.bb-homelab.local {
       tls internal
       reverse_proxy kuma:3001
   }
   ```

3. Reload Caddy without downtime:

   ```bash
   docker exec bb-homelab-caddy caddy reload --config /etc/caddy/Caddyfile
   ```

4. Add the `kuma.bb-homelab.local` line to the client's `/etc/hosts`.

## Phase 2 — migrating to public HTTPS when a domain is bought

When decision #28 (domain purchase) lands, swap `tls internal` for
ACME auto-HTTPS:

```caddyfile
# Before (phase 1)
n8n.bb-homelab.local {
    tls internal
    reverse_proxy n8n:5678
}

# After (phase 2)
n8n.example.com {
    reverse_proxy n8n:5678
}
```

Also set `ACME_EMAIL` in `.env` (for Let's Encrypt renewal notices)
and adjust the client DNS (either public DNS A record, or Tailscale
MagicDNS, depending on the access model chosen at that point). The
internal CA root can then be uninstalled from every client device.

## Security notes

- **Admin API disabled** (`admin off` in Caddyfile). The HTTP API is
  not exposed on any interface; all changes go through the Caddyfile.
- **Caddy listens on host ports 80 + 443** (including UDP 443 for
  HTTP/3). Ensure the host firewall (UFW in `bootstrap/`) allows
  these from the tailnet CIDR but not from the internet. On a
  tailnet-only deploy this is already the default — UFW blocks
  inbound from outside `tailscale0`.
- **No basic auth at this layer yet.** Access control is delegated
  to Tailscale (only devices on the tailnet can resolve the IP).
  When adding services with stronger auth needs (Vaultwarden, etc.),
  layer Caddy's `basicauth` or forward-auth directives per-route.
