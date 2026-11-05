# services/caddy — reverse proxy (phase 1)

Caddy is the single entry point for tailnet traffic to every backend
service in the homelab. It terminates HTTPS (with its own internal CA
in phase 1) and routes host-based requests (`n8n.bb-homelab.local`,
`status.bb-homelab.local`, `jellyfin.bb-homelab.local`, …) to the right
container over that backend's own Docker network (ADR 0009).

Public webhooks (Impropedia widget → n8n) continue to travel through
`cloudflared` directly, untouched by this layer. The two paths are
independent by design — see [ADR 0002](../../docs/decisions/0002-caddy-reverse-proxy.md).

## Stack

- **Caddy 2.11.7** (pinned) — HTTPS termination + host-based routing.
- **One Docker network per backend, `bb-homelab-proxy-<svc>`** —
  external, created once on the host, shared by that backend and Caddy
  only (ADR 0009, #200). Caddy also has its own `edge` bridge for its
  default route and published ports (`gw_priority` needs Docker
  Compose ≥ v2.33.1). Every site is tailnet-only except its exact health
  path; Uptime Kuma also keeps `/api/push/*` open, because the Pi's own
  scripts push through `127.0.0.1` and Caddy sees them from the Docker
  gateway IP.
- **Bind-mount `/mnt/appdata/caddy/data`** — persists the internal CA
  root and issued certificates on the HDD (Pattern Y, like n8n). **Must
  survive container restarts** or Caddy regenerates a brand new root CA
  and every client device's trust anchor becomes stale — hence the
  durable HDD rather than the SD card. The compose declares
  `create_host_path: false`: if the bind source is missing Docker
  refuses to start Caddy instead of auto-creating it on the root
  filesystem. This catches the common "HDD failed to mount" case
  (the source dir lives on the HDD, so it's absent when the disk is
  not mounted) — but it is **not** a full guarantee: if the dirs were
  ever created on the rootfs while the disk was unmounted, Docker would
  bind those instead. The real invariant is "`/mnt/appdata` is
  mounted"; verify it with `mountpoint -q /mnt/appdata` before starting
  the stack (see Bootstrap).
- **Bind-mount `/mnt/appdata/caddy/config`** — Caddy's runtime-managed
  state.

## Bootstrap

Pre-requisite: Docker + Compose v2 on the host.

```bash
# 1. Create one proxy network per backend (once per host, skipping
#    those that already exist).
for s in vaultwarden n8n jellyfin uptime-kuma homepage; do
  docker network inspect "bb-homelab-proxy-$s" >/dev/null 2>&1 \
    || docker network create "bb-homelab-proxy-$s"
done

# 2. Attach each backend to its own network. Every backend compose
#    already declares its network (n8n: services/n8n/docker-compose.yml,
#    and likewise for the others) — just re-up each stack, for example:
#    Exception: uptime-kuma mounts Caddy's root.crt, which exists only
#    after Caddy's first start; re-up it after step 4.
cd services/n8n && docker compose up -d && cd -

# 3. Verify the HDD is actually mounted, THEN create the bind-mount
#    target dirs. The guard matters: `mkdir -p` on an unmounted
#    /mnt/appdata would create the dirs on the root filesystem (SD
#    card), which create_host_path: false would then happily bind.
mountpoint -q /mnt/appdata || { echo "ERROR: /mnt/appdata not mounted"; exit 1; }
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
> mountpoint -q /mnt/appdata || { echo "ERROR: /mnt/appdata not mounted"; exit 1; }
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

1. Create the service's own network on the host
   (`docker network create bb-homelab-proxy-<svc>`) and join it from the
   service's `docker-compose.yml` (see `services/n8n/docker-compose.yml`
   for the pattern). Never join another service's network.
2. Declare that network in `services/caddy/docker-compose.yml`, and add
   the new site name to the aliases on `proxy-uptime-kuma` if Kuma
   probes it.
3. Append a block to `services/caddy/Caddyfile`, with the service's
   exact health path:

   ```caddyfile
   <svc>.bb-homelab.local {
       tls internal
       import tailnet_only /health
       reverse_proxy <svc>:<port>
   }
   ```

4. Recreate Caddy (a new network needs more than a reload; `up -d`
   detects the changed `networks:` and recreates the container):

   ```bash
   docker compose up -d
   ```

5. Add the `<svc>.bb-homelab.local` line to the client's `/etc/hosts`.

## Phase 2 — migrating to public HTTPS when a domain is bought

When decision #28 (domain purchase) lands, swap `tls internal` for
ACME auto-HTTPS:

```caddyfile
# Before (phase 1)
n8n.bb-homelab.local {
    tls internal
    import tailnet_only /healthz
    reverse_proxy n8n:5678
}

# After (phase 2) — keep the tailnet filter
n8n.example.com {
    import tailnet_only /healthz
    reverse_proxy n8n:5678
}
```

Also set `ACME_EMAIL` in `.env` (for Let's Encrypt renewal notices)
and adjust the client DNS (either public DNS A record, or Tailscale
MagicDNS, depending on the access model chosen at that point). The
internal CA root can then be uninstalled from every client device.

## Security notes

- **Admin API enabled on `localhost:2019`, inside the container only.** It
  is not published to any host port or to any backend network, and
  `caddy reload` relies on it to apply Caddyfile changes without a restart.
  The Docker healthcheck probes a plain-HTTP `/healthz` route (not the admin
  API) — see `docker-compose.yml`.
- **Caddy listens on host ports 80 + 443** (including UDP 443 for
  HTTP/3). Ensure the host firewall (UFW in `bootstrap/`) allows
  these from the tailnet CIDR but not from the internet. On a
  tailnet-only deploy this is already the default — UFW blocks
  inbound from outside `tailscale0`.
- **No basic auth at this layer yet.** Caddy enforces network access
  itself: the `tailnet_only` snippet answers 403 to any client outside
  the Tailscale ranges, except each site's exact health path (ADR 0009).
  When adding services with stronger auth needs (Vaultwarden, etc.),
  layer Caddy's `basicauth` or forward-auth directives per-route.

## Sauvegarde

Sauvegarde nocturne et restauration : voir
[storage/APPDATA-BACKUP.md](../../storage/APPDATA-BACKUP.md).
