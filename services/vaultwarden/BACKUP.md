# Vaultwarden — Sauvegarde & Restauration

Procédure pour sauvegarder le répertoire de données de Vaultwarden (base
SQLite, clés de signature JWT, pièces jointes, sends, config admin) et le
restaurer sur le même hôte ou un autre. Définit aussi la copie
**break-glass** et le gate de passage en **Tier-0**.

## Ce qui est sauvegardé

L'archive contient un instantané complet de `/data` dans le conteneur en
cours d'exécution :

- `db.sqlite3` — comptes, items de coffre **chiffrés**, clés
  d'organisation/collection, réglages.
- `rsa_key.pem` / `rsa_key.der` — clés de signature JWT (sessions, push,
  tokens d'invitation).
- `attachments/` — pièces jointes chiffrées.
- `sends/` — blobs Bitwarden Send.
- `config.json` — réglages écrits via le panel `/admin`.

Le fichier SQLite est dumpé via `sqlite3 ".backup"` pour que la copie
soit cohérente même si Vaultwarden écrit au moment de l'instantané.

## Ce qui n'est PAS sauvegardé

- **Ton mot de passe maître.** Les items du coffre restent chiffrés avec
  lui ; l'archive seule ne peut pas les déchiffrer. C'est voulu (le
  backup n'est pas un coffre en clair) — mais ça implique qu'une
  restauration n'est utile qu'à qui connaît encore le mot de passe
  maître. Garde-le dans un second gestionnaire de mots de passe.
- **`VW_ADMIN_TOKEN`.** Il vit dans `services/vaultwarden/.env` (hors de
  `/data`), donc il n'est pas dans l'archive. Garde son **clair** dans
  ton gestionnaire de mots de passe.

Si tu perds le mot de passe maître, les items chiffrés sont
irrécupérables. Aucun backup n'y change rien.

## Copie break-glass — à garder hors-Pi

Tant que Vaultwarden n'est **pas encore Tier-0** (voir le gate ci-dessous),
ne lui fais pas confiance comme unique détenteur d'un secret critique.
Garde une copie d'urgence de trois choses, hors du Pi, jamais en clair :

1. **Un export chiffré du coffre** — dans le Web Vault : *Tools → Export
   Vault → format protégé par mot de passe (chiffré)*. C'est la copie
   récupérable par l'utilisateur qui **ne dépend pas** du serveur, de la
   `rsa_key`, ni du Pi vivant — importable dans n'importe quel
   Bitwarden / Vaultwarden.
2. **Le clair de `VW_ADMIN_TOKEN`** — dans ton gestionnaire de mots de
   passe, pour que `/admin` reste récupérable même si `.env` est perdu.
3. **Une copie de `rsa_key.pem` + `config.json`** (depuis une archive de
   backup) — permet de restaurer l'identité exacte du serveur, pas
   seulement les données.

Stocke (1) et (3) dans un emplacement chiffré (le coffre-fort de fichiers
de ton gestionnaire, ou un blob chiffré `age`/`restic` sur le laptop) —
jamais en clair, jamais uniquement sur la carte SD du Pi.

## Graduation vers Tier-0 (les quatre verts)

Ne promouvoir Vaultwarden en dépendance Tier-0 que lorsque :

1. **Backup unifié hors-site** — `restic` de `BACKUP_DIR` vers Backblaze
   B2 / Hetzner Storage Box, avec le Disque C monté en `/mnt/backup`
   (issues #19 / #47). Stratégie 3-2-1, local conservé en plus du distant.
2. **Restore drill réussi** — une restauration end-to-end (extraction →
   `PRAGMA integrity_check` → démarrage d'une instance jetable →
   connexion) effectuée et documentée.
3. **Sonde Uptime Kuma verte** — sonde HTTP sur `/alive`, branchée au
   canal Telegram fault-only (ADR 0004).
4. **Dead-man's-switch vert** — Healthchecks.io couvre le Pi (ADR 0004).

D'ici là, ton gestionnaire de mots de passe actuel reste la source de
vérité pour les secrets les plus critiques.

## Backup — exécution manuelle

```bash
cd services/vaultwarden
./scripts/backup.sh
```

Comportement par défaut :

- Écrit dans `/var/backups/vaultwarden/vaultwarden-AAAA-MM-JJ_HHMMSS.tar.gz`
- Garde les 7 dernières archives, supprime les plus anciennes.
- L'archive est `chmod 600` (lisible seulement par l'utilisateur qui a
  lancé le script).

Overrides :

```bash
BACKUP_DIR=/mnt/backup/vaultwarden \
KEEP=14 \
./scripts/backup.sh
```

Utiliser l'override `BACKUP_DIR` une fois le stockage de backup dédié
(HDD C, voir issues #19 / #47) en place — bascule proprement de
l'emplacement SD temporaire vers le HDD sans éditer le script.

La première exécution a besoin d'un `/var/backups/vaultwarden`
inscriptible. En utilisateur non-root, le créer une fois :

```bash
sudo install -d -o "$USER" -g "$USER" -m 700 /var/backups/vaultwarden
```

## Backup — planifié via cron

Éditer la crontab de l'utilisateur qui possède Docker (probablement
`benoit`) :

```bash
crontab -e
```

Ajouter une exécution nocturne à 03h05 — décalée de cinq minutes après le
job n8n (03h00) pour éviter la contention HDD. Le log va à côté des
archives, dans un répertoire que l'utilisateur possède déjà :

```cron
5 3 * * *  /home/benoit/bb-homelab/services/vaultwarden/scripts/backup.sh >> /var/backups/vaultwarden/backup.log 2>&1
```

Vérifier avec :

```bash
crontab -l | grep backup.sh
# Attendre une nuit, puis :
ls -lt /var/backups/vaultwarden/
tail -n 20 /var/backups/vaultwarden/backup.log
```

## Restauration — même hôte

Restauration sur le même Pi, même version de Vaultwarden.

> **Pré-requis** : le HDD doit être monté sur `/mnt/appdata`
> (`mountpoint -q /mnt/appdata`). Le compose utilise
> `create_host_path: false`, donc Vaultwarden refuse de démarrer si la
> source du bind-mount manque — restaurer dans le disque monté.

```bash
# 1. Arrêter la stack (NE PAS supprimer le répertoire de données encore).
cd services/vaultwarden
docker compose down

# 2. Choisir l'archive à restaurer.
ARCHIVE=/var/backups/vaultwarden/vaultwarden-2026-06-03_030500.tar.gz

# 3. Les données vivent à un chemin de bind-mount hôte fixe.
VOL_PATH=/mnt/appdata/vaultwarden
echo "${VOL_PATH}"

# 4. Vider + extraire sur place (sudo : le dir appartient au root du
#    conteneur). La forme find supprime aussi les dotfiles.
sudo find "${VOL_PATH:?}" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
sudo tar -xzf "${ARCHIVE}" -C "${VOL_PATH}"

# 5. Redémarrer la stack.
docker compose up -d

# 6. Confirmer : ouvrir https://vaultwarden.bb-homelab.local et se
#    connecter. Si le Web Vault charge mais les sessions sont invalides,
#    la rsa_key de l'archive diffère de celle qui tournait — re-logger
#    tous les appareils.
```

## Restauration — autre hôte (ou Pi neuf)

Même flux que ci-dessus, plus deux pré-requis avant l'étape 1 :

1. `services/vaultwarden/.env` doit exister avec le **même**
   `VW_ADMIN_TOKEN` voulu pour `/admin` (récupérer le clair depuis le
   gestionnaire et re-hasher, ou réutiliser le hash stocké). Les items du
   coffre eux-mêmes sont déchiffrés côté client avec le mot de passe
   maître, indépendamment de `.env`.

2. Le répertoire cible du bind-mount doit exister avant la restauration :

   ```bash
   sudo mkdir -p /mnt/appdata/vaultwarden
   sudo chmod 700 /mnt/appdata/vaultwarden
   ```

   Puis suivre les étapes 2-5 ci-dessus (pas besoin de démarrer la stack
   d'abord — le chemin du bind-mount est créé à la main).

## Vérifier qu'une archive est restaurable

Périodiquement (avant une mise à niveau de l'OS du Pi, une migration de
volume vers le HDD, etc.), vérifier une restauration end-to-end sur un
emplacement jetable :

```bash
mkdir -p /tmp/vw-restore-test
tar -xzf "$(ls -1t /var/backups/vaultwarden/*.tar.gz | head -n1)" \
  -C /tmp/vw-restore-test
sqlite3 /tmp/vw-restore-test/db.sqlite3 'PRAGMA integrity_check;'
# Attendu : "ok"
ls /tmp/vw-restore-test/rsa_key.pem && echo "rsa_key présente"
rm -rf /tmp/vw-restore-test
```

Un `integrity_check` en échec signifie que l'archive est corrompue —
ouvrir un incident et garder l'archive précédente comme copie de travail.

## Rotation & stockage

- Actuel : 7 instantanés quotidiens sur SD (`/var/backups/vaultwarden/`).
  Un petit coffre mono-utilisateur compresse à quelques Mo ; 7 × quelques
  Mo sur SD, c'est négligeable.
- Cible (une fois le HDD C en place) : déplacer `BACKUP_DIR` vers
  `/mnt/backup/vaultwarden/`, étendre `KEEP` à 14 ou 30.
- Cible (une fois le hors-site en place, issue #19) : ajouter un second
  job qui `restic` le `BACKUP_DIR` local vers Backblaze B2 / Hetzner
  Storage Box. Ne pas remplacer les backups locaux par le distant —
  garder les deux (3-2-1). C'est le critère 1 du gate Tier-0 ci-dessus.

## Refs

- Issue #25 — déploiement de Vaultwarden.
- Issue #19 — backups hors-site (restic) de `BACKUP_DIR`.
- ADR [0004](../../docs/decisions/0004-monitoring-architecture.md) —
  monitoring (sonde Uptime Kuma, dead-man's-switch Healthchecks.io).
- ADR [0005](../../docs/decisions/0005-vaultwarden-deployment.md) —
  déploiement Vaultwarden + gating backup-avant-Tier-0.
