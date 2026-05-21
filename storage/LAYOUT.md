# Convention de layout `/mnt` — Pattern Y

Ce document fige la disposition des points de montage sous `/mnt/` pour
que chaque service, script de backup et `docker-compose.yml` puisse
référencer un chemin **stable** et **prévisible**. Il évite les
symlinks morts, les binds compose cassés et les chemins ad-hoc jamais
nettoyés.

Voir [INVENTORY.md](INVENTORY.md) pour le registre matériel (modèles,
UUID, baseline SMART) et [README.md](README.md) pour la vue d'ensemble
de la couche 1 (Storage).

## Les 4 rôles

Les points de montage sont nommés **par usage**, jamais par marque ni
modèle de disque (un disque peut être remplacé sans renommer le chemin).

| Point de montage | Rôle | Contenu | Disque |
|---|---|---|---|
| `/mnt/appdata` | `appdata` | Volumes applicatifs vivants : n8n, Caddy, futurs Postgres / Kuma… | Disque A (rapide) |
| `/mnt/archive` | `archive` | Documents admin (T0), photos (T1), vidéos (T2) | Disque A (rapide) |
| `/mnt/media` | `media` | Films, séries, musique (Jellyfin) | Disque B (média) |
| `/mnt/backup` | `backup` | Snapshots restic, dumps SQLite n8n | Disque C (backup) |

Les labels `T0`/`T1`/`T2` désignent les tiers de données (criticité
décroissante : docs admin → photos → vidéos).

## Pattern Y — 1 rôle par disque

**Pattern Y** = un rôle principal par disque physique, pas de RAID, pas
de LVM (cf. décision #27 sur la stratégie de redondance). Quatre rôles
répartis sur trois disques (`appdata`+`archive` partagent le Disque A
car tous deux « accès rapide »).

```text
Disque A (rapide)   ── /mnt/appdata   (+ /mnt/archive, différé)
Disque B (média)    ── /mnt/media
Disque C (backup)   ── /mnt/backup
```

Avantages : pannes isolées (un disque mort n'emporte qu'un rôle),
sauvegarde et restauration par rôle triviales, pas de couche
d'abstraction à déboguer. La redondance vient de la stratégie 3-2-1
(voir README §3-2-1), pas d'un RAID.

## État actuel

Seul le Disque A est intégré (phase 1, 2026-05-08, PR #79) :

| Rôle | Point de montage | État |
|---|---|---|
| `appdata` | `/mnt/appdata` | ✅ monté — Disque #7 (Seagate BarraCuda 2.5), label `bb-appdata` |
| `archive` | `/mnt/archive` | ⏳ différé (1 partition unique sur Disque A, intégration ultérieure) |
| `media` | `/mnt/media` | ⛔ en attente du Disque B + enclosures (#47) |
| `backup` | `/mnt/backup` | ⛔ en attente du Disque C + enclosures (#47) |

Tant qu'un rôle n'est pas monté, **aucun service ne doit y écrire** : un
bind-mount sur un `/mnt/<role>` non monté retomberait silencieusement
sur la carte SD (rootfs). Les services protègent ce cas avec
`create_host_path: false` côté compose (cf. n8n, Caddy), mais
l'invariant réel reste « le disque est monté » — vérifier avec
`mountpoint -q /mnt/<role>` avant tout démarrage.

## Convention fstab

Chaque disque est monté **par UUID** (jamais par `/dev/sdX`, qui peut
changer d'un boot à l'autre) avec l'option **`nofail`** (le boot
survit à un disque débranché) :

```text
UUID=<uuid>  /mnt/<role>  ext4  defaults,nofail  0  2
```

Label de système de fichiers explicite : `bb-<role>` (ex. `bb-appdata`).
Procédure complète d'intégration d'un disque : voir
[INVENTORY.md](INVENTORY.md) §"Procédure d'intégration condensée".

## Pour les nouveaux services

Un service à état persistant choisit son rôle ; son répertoire est
`/mnt/<role>/<service>/`. On y bind-monte soit le **répertoire entier**
pour un service mono-volume (ex. n8n → `/mnt/appdata/n8n`), soit des
**sous-répertoires** pour un service multi-volumes (ex. Caddy →
`/mnt/appdata/caddy/data` + `/config`). Le skill `/new-service`
applique cette convention par défaut. Ne jamais utiliser `./data` ni un
volume nommé sur la carte SD pour des données qu'on veut durables.
