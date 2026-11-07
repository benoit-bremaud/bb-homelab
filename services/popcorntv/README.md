# services/popcorntv

PopCornTV, l'application média maison, remplace Jellyfin : films et séries
diffusés sur le tailnet via `https://popcorntv.bb-homelab.local`
(issue #240).

Source et décisions : dépôt
[benoit-bremaud/popcorntv](https://github.com/benoit-bremaud/popcorntv),
ADR-0013 et `deploy/homelab/` (copie de référence de ce compose et du bloc
Caddy, à garder alignée).

## Stack

- Image : `popcorntv:${POPCORNTV_VERSION}`, construite sur le Pi depuis un
  tag de release (ou un SHA de `main` avant la première release) ; aucun
  registre.
- Deux services :
  - `popcorntv` : l'API (port `3000`, non publié), en lecture seule,
    `cap_drop: ALL` ;
  - `web-sync` : tâche ponctuelle qui copie le build web de l'image dans
    le volume `popcorntv-web` servi par Caddy, avant le démarrage de l'API.
    Les anciens assets hachés sont gardés 30 jours.
- Données (bind-mounts HDD, Pattern Y, `create_host_path: false`) :

  | Hôte | Conteneur | Contenu | Mode |
  |---|---|---|---|
  | `/mnt/appdata/popcorntv/data` | `/app/data` | base SQLite (sauvegardée) | uid 1000 |
  | `/mnt/appdata/popcorntv/cache` | `/app/cache` | affiches, transcodage (reconstructible) | uid 1000 |
  | `/mnt/appdata/media` | `/app/media` | médiathèque, **temporaire** jusqu'à `/mnt/media` (#47) | lecture seule |
  | volume `popcorntv-web` | `/srv/web` | build web | lecture seule dans Caddy |

- Réseau : `bb-homelab-proxy-popcorntv` (`10.203.60.0/29`, partagé avec
  Caddy seul, ADR 0009). Caddy y a l'IP fixe `10.203.60.2` (`TRUST_PROXY`),
  l'app `10.203.60.3`. Aucun port publié.

## Bootstrap

Sur le Pi (`ssh benoit@bb-homelab`), le disque appdata monté :

```bash
mountpoint -q /mnt/appdata || { echo "ERREUR : /mnt/appdata non monté"; exit 1; }

# 1. Sortir la médiathèque de l'arbre Jellyfin (même disque, instantané)
[ -e /mnt/appdata/media ] || sudo mv /mnt/appdata/jellyfin/media /mnt/appdata/media
sudo install -d -o 1000 -g 1000 /mnt/appdata/popcorntv/data /mnt/appdata/popcorntv/cache
# Dossier de sauvegarde, attendu dès maintenant par la copie nocturne vers le PC
install -d -m 700 ~/backups/popcorntv

# 2. Construire l'image
git clone https://github.com/benoit-bremaud/popcorntv.git ~/popcorntv
cd ~/popcorntv && git checkout <tag-ou-sha> && docker build -t popcorntv:<tag-ou-sha> .

# 3. Réseau et volume partagés avec Caddy (une fois)
docker network create --subnet 10.203.60.0/29 bb-homelab-proxy-popcorntv
docker volume create popcorntv-web

# 4. Configuration et démarrage
cd ~/bb-homelab/services/popcorntv
cp .env.example .env                       # POPCORNTV_VERSION=<tag-ou-sha>
cp popcorntv.env.example popcorntv.env     # jeton TMDB
chmod 600 .env popcorntv.env
docker compose up -d
```

Puis recréer Caddy (`services/caddy`, `docker compose up -d`) : il rejoint
le réseau et monte le volume. Lire le lien de configuration initiale dans
`docker logs bb-homelab-popcorntv`, créer le compte propriétaire, ajouter
les bibliothèques sous `/app/media`, lancer un scan.

Uptime Kuma : moniteur HTTP sur
`https://popcorntv.bb-homelab.local/api/health`, au moins deux essais.

Sur chaque client, ajouter à `/etc/hosts` :

```text
100.121.134.61  popcorntv.bb-homelab.local
```

## Ajouter du contenu

Mêmes règles de droits, d'arborescence (`films/`, `series/`) et de nommage
que dans le [README Jellyfin](../jellyfin/README.md#ajouter-du-contenu),
avec le nouveau chemin :

```bash
scp "/chemin/mon_film.mkv" \
  "benoit@bb-homelab:/mnt/appdata/media/films/Titre (Année).mkv"
```

## Mise à jour et retour arrière

1. Lancer la sauvegarde à la main (ligne cron de
   [APPDATA-BACKUP.md](../../storage/APPDATA-BACKUP.md)).
2. Construire le nouveau tag, changer `POPCORNTV_VERSION` dans `.env`,
   `docker compose up -d` : `web-sync` copie le nouveau build web, les
   migrations tournent au démarrage.

Retour arrière : remettre le tag précédent. Si la nouvelle version a migré
la base, restaurer d'abord l'archive de l'étape 1 (app arrêtée, remettre
`popcorntv.sqlite` avec ses fichiers `-wal` et `-shm` ensemble).

## Sauvegarde

Sauvegarde nocturne de `/app/data` à 03:25 et restauration : voir
[storage/APPDATA-BACKUP.md](../../storage/APPDATA-BACKUP.md). Le cache et
les médias ne sont pas sauvegardés ici.

## Retrait de Jellyfin

Jellyfin reste arrêté avec sa configuration pendant deux semaines après la
bascule, comme solution de repli, puis son service, son réseau proxy, sa
route Caddy et `/mnt/appdata/jellyfin` sont retirés de bb-homelab.
