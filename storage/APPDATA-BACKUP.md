# Sauvegarde des données Caddy, Uptime Kuma, PopCornTV, Jellyfin et Forgejo

Sauvegarde nocturne de la PKI Caddy, des données Uptime Kuma, de la base
PopCornTV (#240), de la configuration Jellyfin et de tout l'état de
Forgejo (#260), avec la procédure de restauration (issue #138).

> **Jellyfin : sauvegarde suspendue depuis le 2026-11-05.** Le service est
> arrêté en attendant PopCornTV ; sa ligne cron (`20 3 * * *`, ci-dessous)
> est retirée du crontab du Pi et le moniteur `backup-jellyfin` est en
> pause. La dernière archive date de la nuit du 2026-11-05. Remettre la
> ligne et réactiver le moniteur si le service est relancé. Jellyfin est
> retiré deux semaines après la bascule vers PopCornTV.

## Ce qui est sauvegardé

| Service | Conteneur | Chemin sauvegardé | Contenu | Dossier d'archive |
|---|---|---|---|---|
| `caddy` | `bb-homelab-caddy` | `/data` | CA interne (racine + intermédiaire), certificats émis | `data/` |
| `uptime-kuma` | `bb-homelab-uptime-kuma` | `/app/data` | `kuma.db` (moniteurs, notifications, historique) | `app_data/` |
| `popcorntv` | `bb-homelab-popcorntv` | `/app/data` | base SQLite (comptes, bibliothèques, progression) | `app_data/` |
| `jellyfin` | `bb-homelab-jellyfin` | `/config` | bibliothèques, utilisateurs, réglages | `config/` |
| `forgejo` | `bb-homelab-forgejo` | `/var/lib/gitea` | dépôts git, base SQLite, `app.ini`, clé d'hôte SSH | `var_lib_gitea/` |

Non sauvegardés : `/config` de Caddy (régénéré au démarrage), `/cache` de
Jellyfin et `/app/cache` de PopCornTV (reconstructibles) et les médias
(`/mnt/appdata/media`, ex-`/mnt/appdata/jellyfin/media`).

Perdre la CA Caddy oblige à refaire confiance à la nouvelle racine sur
chaque client ; l'archive `caddy` contient donc la **clé privée de la CA**.
Elle est en `chmod 600` sur le Pi comme sur le PC : ne jamais la copier
ailleurs en clair.

L'archive `forgejo` contient tous les dépôts et `custom/conf/app.ini`
(jetons internes, copie de `FORGEJO_SECRET_KEY`) : même règle.

## Fonctionnement

[`scripts/appdata-backup.sh`](scripts/appdata-backup.sh) met le conteneur en
pause (une à deux secondes), copie les chemins avec `docker cp -a`, relance
le conteneur, puis écrit une archive atomique `~/backups/<service>/<service>-AAAA-MM-JJ_HHMMSS.tar.gz`
et garde les 7 dernières (`KEEP`). La pause rend cohérents la base SQLite
et son WAL. `docker cp` passe par le démon Docker : `benoit` lit les
dossiers appartenant à root sans `sudo`.

Une exécution réussie envoie un ping au moniteur Push Uptime Kuma du service ;
le PC récupère ensuite les archives (voir [OFFPI-COPY.md](OFFPI-COPY.md)).

## Installation sur le Pi (une fois)

1. Dans Uptime Kuma, créer les moniteurs **Push** : `backup-caddy`,
   `backup-uptime-kuma`, `backup-popcorntv`, `backup-jellyfin`,
   `backup-forgejo`, intervalle `93600` s, 0 retry,
   notification `BB Infra Alerts` (même réglage que `backup-n8n`).
2. Enregistrer chaque URL hors de git :

   ```bash
   install -d -m 700 ~/.config/bb-homelab
   (umask 077; printf '%s' '<URL push>' > ~/.config/bb-homelab/kuma-push-caddy)
   ```

   Idem pour `kuma-push-uptime-kuma`, `kuma-push-popcorntv`,
   `kuma-push-jellyfin` et `kuma-push-forgejo`.
3. Ajouter à `crontab -e`, décalé après n8n (03:00) et Vaultwarden (03:05) :

   ```cron
   10 3 * * * mkdir -p /home/benoit/backups/caddy && KUMA_PUSH_URL="$(cat /home/benoit/.config/bb-homelab/kuma-push-caddy)" /home/benoit/bb-homelab/storage/scripts/appdata-backup.sh caddy bb-homelab-caddy /data >> /home/benoit/backups/caddy/backup.log 2>&1
   15 3 * * * mkdir -p /home/benoit/backups/uptime-kuma && KUMA_PUSH_URL="$(cat /home/benoit/.config/bb-homelab/kuma-push-uptime-kuma)" /home/benoit/bb-homelab/storage/scripts/appdata-backup.sh uptime-kuma bb-homelab-uptime-kuma /app/data >> /home/benoit/backups/uptime-kuma/backup.log 2>&1
   20 3 * * * mkdir -p /home/benoit/backups/jellyfin && KUMA_PUSH_URL="$(cat /home/benoit/.config/bb-homelab/kuma-push-jellyfin)" /home/benoit/bb-homelab/storage/scripts/appdata-backup.sh jellyfin bb-homelab-jellyfin /config >> /home/benoit/backups/jellyfin/backup.log 2>&1
   25 3 * * * mkdir -p /home/benoit/backups/popcorntv && KUMA_PUSH_URL="$(cat /home/benoit/.config/bb-homelab/kuma-push-popcorntv)" /home/benoit/bb-homelab/storage/scripts/appdata-backup.sh popcorntv bb-homelab-popcorntv /app/data >> /home/benoit/backups/popcorntv/backup.log 2>&1
   35 3 * * * mkdir -p /home/benoit/backups/forgejo && KUMA_PUSH_URL="$(cat /home/benoit/.config/bb-homelab/kuma-push-forgejo)" /home/benoit/bb-homelab/storage/scripts/appdata-backup.sh forgejo bb-homelab-forgejo /var/lib/gitea >> /home/benoit/backups/forgejo/backup.log 2>&1
   ```

   Forgejo passe après Immich (03:30, [BACKUP.md](../services/immich/BACKUP.md)).

   La sauvegarde de Kuma met Kuma en pause : un ping reçu pendant ces
   secondes est retenté par `curl --retry 2`, d'où le décalage de 5 min.

## Vérifier une archive

```bash
A="$(ls -1t ~/backups/uptime-kuma/*.tar.gz | head -n1)"
T="$(mktemp -d)" && tar -xzf "$A" -C "$T"
sqlite3 "$T/app_data/kuma.db" 'PRAGMA integrity_check;'   # attendu : ok
rm -rf "$T"
tar -tzf "$(ls -1t ~/backups/caddy/*.tar.gz | head -n1)" | grep 'pki/authorities/local/root.key'
```

Forgejo :

```bash
A="$(ls -1t ~/backups/forgejo/*.tar.gz | head -n1)"
T="$(mktemp -d)" && tar -xzf "$A" -C "$T"
sqlite3 "$T/var_lib_gitea/data/gitea.db" 'PRAGMA integrity_check;'   # attendu : ok
ls "$T/var_lib_gitea/git/repositories"                               # un dossier par utilisateur
test -s "$T/var_lib_gitea/custom/conf/app.ini" && echo "app.ini présent"
rm -rf "$T"
```

Pour tester une archive Kuma dans une instance jetable, la lancer avec
`--network none` : sinon elle sonde les services et envoie les alertes
Telegram comme l'instance réelle. Test du 2026-11-02 : `integrity_check`
ok, 10 moniteurs, compte existant (redirection vers `/dashboard`).

## Restauration

Précondition : le disque est monté (`mountpoint -q /mnt/appdata`). Les
compose utilisent `create_host_path: false`.

| Service | Dossier compose | Dossier d'archive | Cible sur l'hôte | Propriétaire |
|---|---|---|---|---|
| `caddy` | `services/caddy` | `data` | `/mnt/appdata/caddy/data` | `0:0` |
| `uptime-kuma` | `services/uptime-kuma` | `app_data` | `/mnt/appdata/uptime-kuma` | `1000:1000` |
| `popcorntv` | `services/popcorntv` | `app_data` | `/mnt/appdata/popcorntv/data` | `1000:1000` |
| `jellyfin` | `services/jellyfin` | `config` | `/mnt/appdata/jellyfin/config` | `0:0` |
| `forgejo` | `services/forgejo` | `var_lib_gitea` | `/mnt/appdata/forgejo` | `1000:1000` |

Exemple pour Uptime Kuma (remplacer les quatre valeurs pour un autre service) :

```bash
cd ~/bb-homelab/services/uptime-kuma
ARCHIVE=~/backups/uptime-kuma/uptime-kuma-2026-11-03_031500.tar.gz
SRC=app_data
DEST=/mnt/appdata/uptime-kuma
OWNER=1000:1000
case "${DEST}" in /mnt/appdata/?*) OK=1 ;; *) OK=0 ;; esac

if [ "${OK}" = 1 ] && mountpoint -q /mnt/appdata && test -d "${DEST}"; then
  docker compose down
  sudo find "${DEST}" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
  sudo tar -xzf "${ARCHIVE}" -C "${DEST}" --strip-components=2 "./${SRC}"
  sudo chown -R -h "${OWNER}" "${DEST}"
  docker compose up -d
else
  echo "STOP: DEST invalide ou disque non monté (${DEST})"
fi
```

Le garde-fou refuse toute cible hors de `/mnt/appdata/<service>` avant
d'effacer quoi que ce soit, et `chown -h` ne suit pas un lien symbolique
qui se trouverait dans l'archive.

Lancé sans root, `docker cp` écrit les fichiers au nom de `benoit`
(`1000`) : le `chown` remet le propriétaire d'origine.

**Caddy :** `0:0` est obligatoire, sinon Caddy ne démarre pas (voir le
[README Caddy](../services/caddy/README.md#durcissement-du-conteneur-131)).

Pour une archive copiée sur le PC, la renvoyer d'abord sur
le Pi avec `scp`.

**Forgejo :** `.env` doit porter la même `FORGEJO_SECRET_KEY` qu'au
moment de la sauvegarde. Après la restauration, ouvrir un dépôt dans le
navigateur, puis lancer `git ls-remote` en SSH depuis un client : la clé
d'hôte SSH est restaurée, aucun client ne voit d'alerte. Le test de
restauration reste à faire au premier déploiement (#260), puis après
chaque montée de version majeure ; noter la date et le résultat dans
`PROJECT_LOG.md`.

Après une restauration Caddy, la CA est identique : aucun client n'a à
refaire confiance. Restaurer Caddy en dernier si plusieurs services sont
concernés, car c'est lui qui expose les autres.

Couper Caddy coupe aussi l'accès aux autres services : prévoir la
restauration depuis une session SSH Tailscale, qui ne passe pas par Caddy.

## Limites

- La copie est bornée à 120 secondes (`appdata-backup.sh`). Si les dépôts
  Forgejo grossissent au-delà, la sauvegarde échoue, le conteneur reprend
  et le moniteur Push alerte : passer alors à `forgejo dump` ou à une
  copie par `rsync`.
- Le conteneur ne répond pas pendant la pause.
