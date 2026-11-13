# services/uptime-kuma

Supervision « service up/down » du homelab : sondes HTTP/TCP/ping,
historique de disponibilité, et notifications (Telegram, etc.). Premier
composant de la Stack B monitoring (issue #44 ; Beszel — métriques
système — suivra).

## Stack

- Image : `louislam/uptime-kuma:2.5.9-slim` (variante sans Chromium ni
  MariaDB intégré : aucune sonde « real browser », base SQLite ; épinglée —
  bump délibéré via `.env`). Retour arrière : tag sans `-slim` (requis si
  une sonde « real browser » est ajoutée).
- Données persistantes : bind-mount `/mnt/appdata/uptime-kuma/` (HDD,
  Pattern Y) → `/app/data` dans le conteneur (SQLite + config).
- Réseau : `bb-homelab-proxy-uptime-kuma` (partagé avec Caddy seul,
  ADR 0009) + `default`. Kuma fait confiance à la CA interne de Caddy
  (`root.crt` seul, monté en lecture seule).
- URL interne : `https://status.bb-homelab.local` (via Caddy).

## Bootstrap

Prérequis : Caddy a démarré au moins une fois (il génère `root.crt`,
que Kuma monte en lecture seule ; ses dossiers sont réservés à root,
d'où le `sudo` du contrôle) et le réseau
`bb-homelab-proxy-uptime-kuma` existe (voir `services/caddy/README.md`).

```bash
cd services/uptime-kuma
sudo test -f /mnt/appdata/caddy/data/caddy/pki/authorities/local/root.crt \
  || { echo "ERREUR : root.crt absent, démarrer Caddy d'abord"; exit 1; }
cp .env.example .env
# Éditer .env si besoin (TZ, tag d'image)
# Créer la cible bind-mount sur le HDD (le disque doit être monté) :
mountpoint -q /mnt/appdata || { echo "ERREUR : /mnt/appdata non monté"; exit 1; }
sudo mkdir -p /mnt/appdata/uptime-kuma
docker compose up -d
docker compose logs -f uptime-kuma
```

Puis, sur chaque poste client, router le hostname vers l'IP Tailscale
du Pi (cf. `services/caddy/README.md`) :

```text
100.121.134.61  status.bb-homelab.local
```

Sur le Pi lui-même, les pushes (sauvegardes, Home Assistant) passent
par Caddy en loopback, sans dépendre de Tailscale :

```text
127.0.0.1  status.bb-homelab.local
```

`bootstrap/bootstrap.sh` (étape hostname) pose cette ligne dans
`/etc/hosts` **et** dans `/etc/cloud/templates/hosts.debian.tmpl` :
cloud-init (`manage_etc_hosts: true`) réécrit `/etc/hosts` depuis ce
template à chaque boot, une ligne ajoutée à la main est donc perdue au
redémarrage (incident #161). Après un changement de `/etc/hosts`,
redémarrer les conteneurs qui en gardent une copie (ex.
`homeassistant`).

## Configuration (post-démarrage, via l'UI)

À la première ouverture de `https://status.bb-homelab.local` :

1. Créer le compte administrateur (login + mot de passe → gestionnaire
   de mots de passe). Aucun secret n'est stocké dans `.env`.
2. Ajouter une sonde par service interne, **via Caddy en HTTPS**
   (ADR 0009) : Kuma n'a plus accès direct aux autres backends. Seul
   le chemin de santé exact de chaque site est ouvert hors tailnet ;
   régler chaque sonde à au moins deux essais (une recréation de Caddy
   les fait toutes tomber ensemble). Ex. :
   - n8n : `https://n8n.bb-homelab.local/healthz`
   - PopCornTV : `https://popcorntv.bb-homelab.local/api/health`
   - Vaultwarden : `https://vaultwarden.bb-homelab.local/alive`
   - Homepage : `https://home.bb-homelab.local/api/healthcheck`
   - Immich : `https://immich.bb-homelab.local/api/server/ping`
3. Brancher le canal de notification Telegram (token bot + chat ID
   depuis le gestionnaire de mots de passe). Le bot utilisé est
   `@bb_infra_alerts_bot`, voir [Bots Telegram](../../docs/telegram-bots.md).

## Opérations

- Logs : `docker compose logs -f uptime-kuma`.
- Backup : les données vivent dans `/mnt/appdata/uptime-kuma/`
  (sauvegardées avec le reste du HDD). `kuma.db` est une base SQLite.
- Mise à jour : bumper `UPTIME_KUMA_IMAGE_TAG` dans `.env`, puis
  `docker compose pull && docker compose up -d`.

## Sauvegarde

Sauvegarde nocturne et restauration : voir
[storage/APPDATA-BACKUP.md](../../storage/APPDATA-BACKUP.md).
