# services/uptime-kuma

Supervision « service up/down » du homelab : sondes HTTP/TCP/ping,
historique de disponibilité, et notifications (Telegram, etc.). Premier
composant de la Stack B monitoring (issue #44 ; Beszel — métriques
système — suivra).

## Stack

- Image : `louislam/uptime-kuma:2.5.7` (épinglée — bump délibéré via
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

## Sauvegarde

Sauvegarde nocturne et restauration : voir
[storage/APPDATA-BACKUP.md](../../storage/APPDATA-BACKUP.md).
