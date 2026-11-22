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
- **cloudflared** — tunnel Cloudflare nommé : expose n8n en HTTPS sur
  le nom public stable `n8n.benoitbremaud.fr`, sans redirection de port
  (#143, [ADR 0012](../../docs/decisions/0012-n8n-named-cloudflare-tunnel.md)).
  Il remplace le tunnel rapide `*.trycloudflare.com`, dont le nom
  changeait à chaque recréation et qui ne transporte pas les
  Server-Sent Events dont le serveur MCP de n8n a besoin.
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
# Renseigner dans .env : N8N_HOST, N8N_WEBHOOK_URL et
# CLOUDFLARE_TUNNEL_TOKEN (voir « Tunnel nommé » plus bas).
docker compose up -d
```

Then:

```bash
# Check both containers are healthy
docker compose ps
# Tunnel connecté (attendu : « Registered tunnel connection »)
docker compose logs cloudflared | grep -i "registered tunnel connection"
# Nom public de bout en bout (attendu : 200)
curl -s -o /dev/null -w '%{http_code}\n' https://n8n.benoitbremaud.fr/healthz
# Access the n8n UI locally
# http://localhost:5678
```

On first start, n8n will prompt for an admin account creation.

## Environment variables

| Variable | Role |
|---|---|
| `N8N_ENCRYPTION_KEY` | Encrypts all credentials stored in n8n. **Lose it = lose them**. Must stay identical across migrations. |
| `TZ` | Timezone (default `Europe/Paris`). |
| `N8N_HOST` | Nom public servi par n8n : `n8n.benoitbremaud.fr`. |
| `N8N_WEBHOOK_URL` | URL publique de base, avec la barre finale : `https://n8n.benoitbremaud.fr/`. n8n en tire les URL absolues des webhooks (celle du widget Impropedia par exemple). Remplace `WEBHOOK_URL`, dépréciée depuis n8n 2.35 (#151). |
| `CLOUDFLARE_TUNNEL_TOKEN` | Jeton du tunnel nommé, passé à cloudflared comme `TUNNEL_TOKEN`. Secret : `.env` du Pi et gestionnaire de mots de passe seulement. Obligatoire. |

`N8N_PROXY_HOPS=1` est fixé dans le compose : un seul proxy
(cloudflared ou Caddy) se tient devant n8n et pose `X-Forwarded-For`.

All sensitive values live in `.env` (gitignored). Never commit `.env`.

## Tunnel nommé

Le tunnel est géré à distance : sa route de nom public vit dans le
tableau de bord Cloudflare, le Pi ne détient que le jeton.

| Élément | Valeur |
|---|---|
| Compte Cloudflare | celui du propriétaire, qui porte la zone `benoitbremaud.fr` |
| Nom du tunnel | `bb-homelab-n8n` |
| Nom public | `n8n.benoitbremaud.fr` → `HTTP` `127.0.0.1:5678` (cloudflared tourne dans le réseau de l'hôte) |
| TLS | certificat du bord Cloudflare ; le HSTS de la zone (`includeSubDomains`, preload) impose HTTPS |
| Jeton | `.env` du Pi (`CLOUDFLARE_TUNNEL_TOKEN`) et gestionnaire de mots de passe ; jamais dans git, un chat ou un journal |
| Échéance du jeton | les jetons de tunnel Cloudflare n'expirent pas : rotation annuelle, prochaine en 2027-11 |

Recréer cloudflared (`docker compose up -d --force-recreate
cloudflared`, montée de version, redémarrage) garde le nom : rien à
repointer.

### Rotation du jeton

Chaque année, ou tout de suite en cas de fuite (consigner alors un
incident de rotation dans `PROJECT_LOG.md`, voir
`.claude/rules/security-invariants.md`).

1. Tableau de bord Cloudflare → Networking → Tunnels → `bb-homelab-n8n`
   → *Rotate token* (ou *Refresh token*). L'ancien jeton n'ouvre plus de
   nouvelle connexion ; la connexion en cours reste active jusqu'au
   redémarrage de cloudflared.
2. *Add a replica* : copier le jeton (`eyJ…`) de la commande
   d'installation, sans l'exécuter, dans le `.env` du Pi
   (`CLOUDFLARE_TUNNEL_TOKEN=`) et dans le gestionnaire de mots de passe.
3. `docker compose up -d --force-recreate cloudflared`.
4. Contrôle : les journaux de cloudflared montrent des connexions
   enregistrées, `https://n8n.benoitbremaud.fr/healthz` renvoie 200.
5. En cas de fuite seulement : couper aussi toutes les connexions du
   tunnel (API Cloudflare, `DELETE …/cfd_tunnel/<id>/connections`).
6. Noter la date de rotation et la suivante dans `PROJECT_LOG.md`.

### Consommateurs du nom public

- Widget de retours Impropedia (dépôt à part) : `POST
  https://n8n.benoitbremaud.fr/webhook/feedback`.
- Connecteur n8n de claude.ai :
  `https://n8n.benoitbremaud.fr/mcp-server/http` (OAuth par n8n).
- Moniteur HTTPS Uptime Kuma du tunnel :
  `https://n8n.benoitbremaud.fr/healthz`.

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
dans l'interface n8n. Tous les bots Telegram, n8n compris, sont
inventoriés dans [Bots Telegram](../../docs/telegram-bots.md).

| Workflow | Déclencheur | Actif | Services appelés | Credential | Bot | Chat Telegram | Dernière exécution | Décision |
|---|---|---|---|---|---|---|---|---|
| Impropedia — Feedback → Telegram | Webhook `POST /webhook/feedback` (tunnel cloudflared) | oui | Telegram (envoi d'un message texte) | `Telegram account` (`telegramApi`) | « Impropedia Feedback » (dédié) | chat du propriétaire (…7563) | 2026-10-24, succès | garder |

C'est le seul workflow et le seul credential présents dans n8n
(`n8n list:workflow`, actifs compris). Le tunnel cloudflared, arrêté du
2026-11-03 au 2026-11-21 (#196), tourne de nouveau (décision du
propriétaire, risque accepté) ; depuis #143 le webhook est joignable
sur le nom stable `n8n.benoitbremaud.fr`. Le Kaggle watcher ne tourne pas dans n8n ;
l'ancien `n8n-watchdog` du portable a été retiré par l'ADR 0004.
