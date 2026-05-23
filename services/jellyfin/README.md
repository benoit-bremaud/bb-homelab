# services/jellyfin

Serveur multimédia self-hosted (« Netflix maison ») : films, séries et
musique diffusés en streaming sur le tailnet, sans compte tiers ni cloud.

## Stack

- Image : `jellyfin/jellyfin:10.11.9` (épinglée — bump délibéré via
  `.env`). Manifeste multi-arch : l'ARM64 est tiré automatiquement sur
  le Pi 5.
- Données persistantes (bind-mounts HDD, Pattern Y, rôle `appdata`) :
  - `/mnt/appdata/jellyfin/config` → `/config` (base, réglages, comptes)
  - `/mnt/appdata/jellyfin/cache` → `/cache` (transcodage, vignettes)
  - `/mnt/appdata/jellyfin/media` → `/media` (médiathèque, **temporaire**)
- Réseau : `bb-homelab-proxy` (partagé avec Caddy) + port `8096` publié
  pour l'accès direct.
- Accès : `https://jellyfin.bb-homelab.local` (via Caddy) ou direct
  `http://bb-homelab:8096` (tailnet/LAN uniquement, aucun ingress
  public — décision #28).

## Médiathèque temporaire sur le Disque A

Pattern Y place la médiathèque sur le rôle `media` (`/mnt/media`,
Disque B). Ce disque n'est **pas encore monté** (issue #47). En
attendant, la médiathèque vit sur le Disque A sous
`/mnt/appdata/jellyfin/media`. C'est un choix **assumé et temporaire** :

- léger écart à Pattern Y (vidéo sur le disque `appdata` rapide) ;
- volume limité (le Disque A n'est pas dimensionné pour une grosse
  vidéothèque) — garder quelques fichiers de test ;
- migration vers `/mnt/media` dès l'arrivée du Disque B (voir
  [ADR 0003](../../docs/decisions/0003-jellyfin-media-server.md)
  §Consequences pour la procédure).

## Bootstrap

Sur le Pi (`ssh benoit@bb-homelab`) :

```bash
cd services/jellyfin
cp .env.example .env
# Éditer .env si besoin (tag, TZ, URL publiée)

# Le disque appdata doit être monté (create_host_path: false sinon
# échec au démarrage) :
mountpoint -q /mnt/appdata || { echo "ERREUR : /mnt/appdata non monté"; exit 1; }
sudo mkdir -p /mnt/appdata/jellyfin/{config,cache,media}

docker compose up -d
docker compose logs -f jellyfin
```

Au premier démarrage, ouvrir `http://bb-homelab:8096` et suivre
l'assistant : créer le compte admin, ajouter une bibliothèque pointant
sur `/media`.

## Ajouter / retirer des médias

Tant que la médiathèque est sur le Disque A, copier les fichiers depuis
ton poste vers le Pi, puis relancer un scan dans l'UI Jellyfin :

```bash
# Depuis ton poste — copie un film dans la bibliothèque
scp -r "Mon Film (2024)" benoit@bb-homelab:/mnt/appdata/jellyfin/media/films/
```

Organisation recommandée (conventions de nommage Jellyfin) :

```text
/mnt/appdata/jellyfin/media/
├── films/
│   └── Titre (Année)/Titre (Année).mkv
└── series/
    └── Série/Season 01/Série S01E01.mkv
```

Puis dans l'UI : **Tableau de bord → Bibliothèques → Analyser**.

## Lecture & transcodage (Pi 5)

Le GPU VideoCore VII du Pi 5 ne transcode pas tous les codecs. Pour une
lecture fluide, privilégier le **Direct Play** : stocker des fichiers
dans des formats lus nativement par tes clients (H.264/AAC en MP4/MKV
est le plus sûr). Éviter de compter sur le transcodage à la volée de
flux 4K HEVC haut débit. Détail du raisonnement : voir
[ADR 0003](../../docs/decisions/0003-jellyfin-media-server.md).

## Opérations

- **Mise à jour** : bump `JELLYFIN_IMAGE_TAG` dans `.env`, puis
  `docker compose pull && docker compose up -d`.
- **Sauvegarde** : `/config` contient toute la configuration (comptes,
  bibliothèques, vues). Inclus dans la stratégie de backup `appdata`.
- **Logs** : `docker compose logs -f jellyfin`.
- **Santé** : `docker inspect --format '{{.State.Health.Status}}' bb-homelab-jellyfin`.

## Route Caddy

Ajoutée à [`services/caddy/Caddyfile`](../caddy/Caddyfile) :

```caddyfile
jellyfin.bb-homelab.local {
    tls internal
    reverse_proxy jellyfin:8096
}
```

Recharger Caddy après modification :

```bash
docker exec bb-homelab-caddy caddy reload --config /etc/caddy/Caddyfile
```

Sur chaque client, ajouter à `/etc/hosts` :

```text
100.121.134.61  jellyfin.bb-homelab.local
```

Pour les apps TV/mobile qui ne savent pas installer la CA interne de
Caddy, utiliser l'accès direct `http://bb-homelab:8096`.

## Refs

- Issue #12 — déploiement du conteneur Jellyfin
- Issue #47 — Disque B + enclosures (débloque `/mnt/media`)
- [ADR 0003](../../docs/decisions/0003-jellyfin-media-server.md) — choix
  de Jellyfin + stratégie média/transcodage
- [storage/LAYOUT.md](../../storage/LAYOUT.md) — convention `/mnt`
  (Pattern Y)
