# services/uptime-kuma

Supervision « service up/down » du homelab : sondes HTTP/TCP/ping,
historique de disponibilité, et notifications (Telegram, etc.). Premier
composant de la Stack B monitoring (issue #44 ; Beszel — métriques
système — suivra).

## Stack

- Image : `louislam/uptime-kuma:2.3.2` (épinglée — bump délibéré via
  `.env`).
- Données persistantes : bind-mount `/mnt/appdata/uptime-kuma/` (HDD,
  Pattern Y) → `/app/data` dans le conteneur (SQLite + config).
- Réseau : `bb-homelab-proxy` (partagé avec Caddy) + `default`.
- URL interne : `https://status.bb-homelab.local` (via Caddy).

## Bootstrap

```bash
cd services/uptime-kuma
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

## Configuration (post-démarrage, via l'UI)

À la première ouverture de `https://status.bb-homelab.local` :

1. Créer le compte administrateur (login + mot de passe → gestionnaire
   de mots de passe). Aucun secret n'est stocké dans `.env`.
2. Ajouter une sonde par service interne, ex. :
   - n8n : `http://n8n:5678/healthz` (réseau `bb-homelab-proxy`)
   - Caddy : `http://caddy:80` (ou la racine d'un service routé)
3. Brancher le canal de notification Telegram (token bot + chat ID
   depuis le gestionnaire de mots de passe).

## Opérations

- Logs : `docker compose logs -f uptime-kuma`.
- Backup : les données vivent dans `/mnt/appdata/uptime-kuma/`
  (sauvegardées avec le reste du HDD). `kuma.db` est une base SQLite.
- Mise à jour : bumper `UPTIME_KUMA_IMAGE_TAG` dans `.env`, puis
  `docker compose pull && docker compose up -d`.
