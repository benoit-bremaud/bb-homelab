# services/homepage

Tableau de bord d'accueil du homelab : un point d'entrée unique qui
liste les services (`*.bb-homelab.local`) et — à partir de la PR2 —
affiche leur statut via Uptime Kuma. Choix de l'outil documenté dans
[ADR 0006](../../docs/decisions/0006-homepage-dashboard.md).

## Stack

- Image : `ghcr.io/gethomepage/homepage:v1.13.2` (épinglée — bump
  délibéré via `.env`, manifeste multi-arch → arm64 sur le Pi 5).
- Configuration : **dans le repo**, bind-mount relatif
  `./config` → `/app/config`. Dérogation délibérée au Pattern Y :
  Homepage n'a aucun état runtime en L1/L2, sa config est du *code*,
  pas de l'*appdata* — donc **pas de dépendance `/mnt/appdata`**, le
  dashboard démarre même HDD démonté (cf. ADR 0006).
- Logs : `LOG_TARGETS=stdout` → aucun fichier écrit dans le dossier
  `config/` suivi par git ; logs via `docker compose logs -f homepage`.
- Réseau : `bb-homelab-proxy` (partagé avec Caddy) + `default`.
- URL interne : `https://home.bb-homelab.local` (via Caddy,
  `tls internal`, tailnet-only).

## Bootstrap

Plus simple que les autres services : aucune étape `/mnt/appdata` (la
config est dans le repo).

```bash
cd services/homepage
cp .env.example .env
# Éditer .env si besoin (TZ, tag d'image, HOMEPAGE_ALLOWED_HOSTS)
docker compose up -d
docker compose logs -f homepage
```

Puis recharger Caddy pour activer la route `home.bb-homelab.local`
(déjà présente dans `services/caddy/Caddyfile`) :

```bash
docker exec bb-homelab-caddy caddy reload --config /etc/caddy/Caddyfile
```

Enfin, sur chaque poste client, router le hostname vers l'IP Tailscale
du Pi (cf. `services/caddy/README.md`) :

```text
100.121.134.61  home.bb-homelab.local
```

Les tuiles du dashboard pointent aussi vers `n8n.bb-homelab.local`,
`jellyfin.bb-homelab.local`, `vaultwarden.bb-homelab.local` et
`status.bb-homelab.local`. Ces hostnames sont déjà dans le `/etc/hosts`
du poste si l'on a suivi le README de chaque service ; sinon, les
ajouter de la même façon (même IP Tailscale du Pi) pour que les liens
résolvent.

## Configuration

Le dashboard est entièrement piloté par les fichiers YAML versionnés
dans `config/` — aucune étape via une UI :

- `settings.yaml` — titre, thème, disposition (groupes).
- `services.yaml` — une tuile par service (n8n, Jellyfin, Vaultwarden,
  Uptime Kuma).
- `widgets.yaml` — en-tête d'information (date/heure).
- `bookmarks.yaml` — signets (vide au niveau 1).

Les fichiers `docker.yaml`, `kubernetes.yaml`, `proxmox.yaml`,
`custom.css` et `custom.js` sont committés vides : Homepage ne crée que
les fichiers manquants au démarrage, donc les committer empêche toute
génération de squelette dans le dossier suivi par git.

**Prérequis PR2 (niveau 2 — widget de statut).** Avant d'ajouter le
widget Uptime Kuma à `services.yaml`, créer dans Uptime Kuma une
*status page* (slug `bb-homelab`) listant les sondes existantes. Le
widget lit cette page publique par slug — sans clé API ni login.

## Opérations

- Logs : `docker compose logs -f homepage`.
- Santé : `docker inspect --format '{{.State.Health.Status}}' bb-homelab-homepage`
  → `healthy` (sonde sur `http://127.0.0.1:3000/api/healthcheck`).
- Mise à jour : bumper `HOMEPAGE_IMAGE_TAG` dans `.env`, puis
  `docker compose pull && docker compose up -d`.
