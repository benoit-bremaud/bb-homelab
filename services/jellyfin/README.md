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

## Ajouter du contenu

> **Important — droits.** N'ajouter que du contenu dont on a les droits :
> créations personnelles, captations de la troupe, films du domaine
> public ou sous licence Creative Commons, fichiers achetés sans DRM. Les
> achats sur les plateformes type Google TV / Netflix sont protégés par
> DRM et ne sont **pas** importables ; contourner ce verrou est illégal.

### Arborescence

Deux bibliothèques distinctes, un dossier racine chacune (sinon Jellyfin
mélange films et épisodes) :

```text
/mnt/appdata/jellyfin/media/
├── films/
│   └── Titre (Année).mkv                 # ou Titre (Année)/Titre (Année).mkv
└── series/
    └── Série (Année)/Season 01/Série S01E01.mkv
```

### Réglage des bibliothèques (une seule fois)

Depuis le navigateur d'un poste du LAN (`http://192.168.1.216:8096`,
compte admin) :

1. **Tableau de bord → Bibliothèques → Movies → Gérer** : retirer le
   dossier `/media`, ajouter `/media/films`, enregistrer.
2. **Ajouter une médiathèque** : type *Shows*, nom *Séries*, dossier
   `/media/series`.

### Règles de nommage (conventions Jellyfin)

- **Film** : `Titre (Année).ext` — ex. `Inception (2010).mkv`. L'année
  entre parenthèses lève les ambiguïtés.
- **Série** : `Série (Année)/Season 01/Série S01E01.ext` — le marqueur
  `SxxEyy` est l'élément reconnu ; les *specials* vont dans `Season 00`.
- **Sous-titres** : même nom que la vidéo + langue, à côté du fichier —
  ex. `Inception (2010).fr.srt`.
- Accents et espaces acceptés. Privilégier H.264/AAC en MP4/MKV pour le
  Direct Play (cf. section transcodage).

### Déposer les fichiers sur le Pi

Le dépôt se fait **côté serveur** (l'interface web Jellyfin ne sert pas à
téléverser). Deux méthodes :

```bash
# A. Glisser-déposer (graphique) — dans l'explorateur de fichiers :
#    « Se connecter à un serveur » →
#    sftp://benoit@bb-homelab/mnt/appdata/jellyfin/media/
#    puis déposer dans films/ ou series/.

# B. Ligne de commande (depuis le poste) :
scp "/chemin/mon_film.mkv" \
  "benoit@bb-homelab:/mnt/appdata/jellyfin/media/films/Titre (Année).mkv"

# Série : créer l'arbo saison d'abord
ssh benoit@bb-homelab 'mkdir -p "/mnt/appdata/jellyfin/media/series/Ma Série (2020)/Season 01"'
scp "/chemin/ep1.mkv" \
  "benoit@bb-homelab:/mnt/appdata/jellyfin/media/series/Ma Série (2020)/Season 01/Ma Série S01E01.mkv"
```

> Le dossier `media/` appartient à `benoit` (dépôt sans `sudo`). À terme,
> un partage Samba pourra exposer ce dossier comme un lecteur réseau.

### Scanner & vérifier

1. Dans l'UI : **Tableau de bord → Bibliothèques → ⋮ → Analyser** (un
   scan automatique a aussi lieu, les dossiers étant surveillés en
   temps réel).
2. Affiche, résumé, année, casting sont récupérés tout seuls de
   TheMovieDb (films) / TheTVDB (séries), et mis en cache dans `/config`.
3. Mal reconnu ? Sur la fiche → **⋮ → Identifier** (recherche manuelle ou
   ID TMDb collé). Contenu perso sans fiche en ligne → **Éditer les
   métadonnées** pour saisir titre / affiche / résumé à la main.

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
