# services/n8n — workflow orchestrator

n8n is the automation hub of the homelab. It runs workflows triggered
by webhooks (e.g. the Impropedia feedback widget), scheduled jobs, or
manual runs, and drives downstream services (Telegram notifications,
GitHub Issue creation via Claude, etc.). It is the first service to
land under `services/` and the one that motivated starting the
homelab.

Originally lived in a separate `impropedia-infra` repo (now archived).
The integration into `bb-homelab/services/n8n/` keeps everything the
homelab needs in one clone.

## Stack

- **n8n** — the orchestrator itself, bound to `127.0.0.1:5678` so the
  outside world can only reach it through the reverse proxy /
  cloudflared tunnel (never directly on a LAN/WAN port).
- **cloudflared** — Cloudflare tunnel exposing n8n as a public HTTPS
  URL without any port forwarding. Ephemeral `*.trycloudflare.com`
  today; named tunnel when a domain is bought (decision #28).
- **bind-mount `/mnt/appdata/n8n`** — host directory on the HDD that
  persists n8n's SQLite DB, encrypted credentials, workflow JSONs.
  Backup target. Migrated from the SD-card Docker named volume
  `bb-homelab-n8n-data` (issue #93) to follow Pattern Y
  (`/mnt/<role>/<service>/` for `appdata` services).

See [BACKUP.md](BACKUP.md) for the backup & restore procedure (manual
run, cron schedule, volume migration across hosts, restore verification).

## Bootstrap

Pre-requisite: Docker + Compose v2 installed by `bootstrap/bootstrap.sh`.

```bash
cd services/n8n
cp .env.example .env
# Replace the empty N8N_ENCRYPTION_KEY= placeholder in-place (avoids
# leaving the original empty line sitting above a duplicate).
sed -i "s|^N8N_ENCRYPTION_KEY=.*|N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)|" .env
# Edit .env to set WEBHOOK_URL / N8N_HOST once cloudflared announces
# its ephemeral URL on first start.
docker compose up -d
```

Then:

```bash
# Check both containers are healthy
docker compose ps
# Grab the public tunnel URL (changes at every cloudflared restart
# unless we switch to a named tunnel)
docker compose logs cloudflared | grep -E "https://[a-z0-9-]+\.trycloudflare\.com"
# Access the n8n UI locally
# http://localhost:5678
```

On first start, n8n will prompt for an admin account creation.

## Environment variables

| Variable | Role |
|---|---|
| `N8N_ENCRYPTION_KEY` | Encrypts all credentials stored in n8n. **Lose it = lose them**. Must stay identical across migrations. |
| `TZ` | Timezone (default `Europe/Paris`). |
| `WEBHOOK_URL` | The public URL cloudflared announces. Used by n8n to build absolute webhook URLs (e.g. what the Impropedia widget posts to). |
| `N8N_HOST` | Hostname n8n serves (set to the cloudflared subdomain). |
| `CLOUDFLARE_TUNNEL_TOKEN` | *(future)* Stable named tunnel token once a Cloudflare domain is bought. |

All sensitive values live in `.env` (gitignored). Never commit `.env`.

## Security notes

- n8n binds on loopback only. Any port exposed to the LAN or the
  internet goes through cloudflared.
- Credentials (Telegram bot token, Anthropic API key, GitHub token)
  are entered once via the n8n UI and stored encrypted inside the
  volume (protected by `N8N_ENCRYPTION_KEY`). They never appear in
  this repo.
- On hosts running UFW, outbound is allowed by default (the
  `bootstrap.sh` baseline). No inbound rule is needed for n8n since
  the public path is cloudflared (outbound to Cloudflare's edge).

## Workflows

JSON exports of n8n workflows live under [workflows/](workflows/).
They document what's currently deployed and let a fresh install
re-import them from the UI (Settings → Import from File). The binary
volume is the source of truth at runtime; workflows JSON in this repo
is the versioned reference.
