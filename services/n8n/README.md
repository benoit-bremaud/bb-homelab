# services/n8n — workflow orchestrator

n8n is the automation hub of the homelab. It runs workflows triggered
by webhooks (e.g. the Impropedia feedback widget), scheduled jobs, or
manual runs, and drives downstream services (Telegram notifications today, see
"Qui fait quoi" below). It is the first service to
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
  **Precondition**: the HDD must be mounted at `/mnt/appdata` before
  `docker compose up`. The compose declares `create_host_path: false`,
  so if the disk is not mounted n8n fails to start (loud) rather than
  silently auto-creating an empty data dir on the SD card. On a fresh
  host, create the directory first (`sudo mkdir -p /mnt/appdata/n8n &&
  sudo chown 1000:1000 /mnt/appdata/n8n`) — see
  [BACKUP.md](BACKUP.md) "Restore — different host".

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
- Credentials (today only the Telegram bot token, see "Qui fait
  quoi" below) are entered once via the n8n UI and stored encrypted inside the
  volume (protected by `N8N_ENCRYPTION_KEY`). They never appear in
  this repo.
- On hosts running UFW, outbound is allowed by default (the
  `bootstrap.sh` baseline). No inbound rule is needed for n8n since
  the public path is cloudflared (outbound to Cloudflare's edge).

## Workflows

[workflows/](workflows/) is meant to hold JSON exports of the n8n
workflows, re-importable from the UI (Settings → Import from File). No
export is versioned yet: the n8n database on the Pi is the only source.

### Qui fait quoi

Inventaire en lecture seule du 2026-11-06 (#222), relevé par
`n8n export:workflow --all` dans le conteneur `bb-homelab-n8n`. Les
credentials sont listés par leur nom uniquement ; leurs valeurs restent
dans l'interface n8n.

| Workflow | Déclencheur | Actif | Services appelés | Credential | Bot | Chat Telegram | Dernière exécution | Décision |
|---|---|---|---|---|---|---|---|---|
| Impropedia — Feedback → Telegram | Webhook `POST /webhook/feedback` (tunnel cloudflared) | oui | Telegram (envoi d'un message texte) | `Telegram account` (`telegramApi`) | « Impropedia Feedback » (dédié) | chat du propriétaire (…7563) | 2026-10-24, succès | garder |

C'est le seul workflow et le seul credential présents dans n8n
(`n8n list:workflow`, actifs compris). Le tunnel cloudflared est arrêté
depuis le 2026-11-03 (#196) : le webhook est injoignable de l'extérieur
tant qu'il ne redémarre pas. Le Kaggle watcher ne tourne pas dans n8n ;
l'ancien `n8n-watchdog` du portable a été retiré par l'ADR 0004.
