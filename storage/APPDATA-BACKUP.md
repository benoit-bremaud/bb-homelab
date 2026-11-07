# Sauvegarde des données Caddy, Uptime Kuma, PopCornTV et Jellyfin

Sauvegarde nocturne de la PKI Caddy, des données Uptime Kuma et de la
base PopCornTV (#240) et de la configuration Jellyfin, avec la procédure
de restauration (issue #138).

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

Non sauvegardés : `/config` de Caddy (régénéré au démarrage), `/cache` de
Jellyfin et `/app/cache` de PopCornTV (reconstructibles) et les médias
(`/mnt/appdata/media`, ex-`/mnt/appdata/jellyfin/media`).

Perdre la CA Caddy oblige à refaire confiance à la nouvelle racine sur
chaque client ; l'archive `caddy` contient donc la **clé privée de la CA**.
Elle est en `chmod 600` sur le Pi comme sur le PC : ne jamais la copier
ailleurs en clair.

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
   `backup-uptime-kuma`, `backup-popcorntv`, `backup-jellyfin`, intervalle `93600` s, 0 retry,
   notification `BB Infra Alerts` (même réglage que `backup-n8n`).
2. Enregistrer chaque URL hors de git :

   ```bash
   install -d -m 700 ~/.config/bb-homelab
   (umask 077; printf '%s' '<URL push>' > ~/.config/bb-homelab/kuma-push-caddy)
   ```

   Idem pour `kuma-push-uptime-kuma`, `kuma-push-popcorntv` et
   `kuma-push-jellyfin`.
3. Ajouter à `crontab -e`, décalé après n8n (03:00) et Vaultwarden (03:05) :

   ```cron
   10 3 * * * mkdir -p /home/benoit/backups/caddy && KUMA_PUSH_URL="$(cat /home/benoit/.config/bb-homelab/kuma-push-caddy)" /home/benoit/bb-homelab/storage/scripts/appdata-backup.sh caddy bb-homelab-caddy /data >> /home/benoit/backups/caddy/backup.log 2>&1
   15 3 * * * mkdir -p /home/benoit/backups/uptime-kuma && KUMA_PUSH_URL="$(cat /home/benoit/.config/bb-homelab/kuma-push-uptime-kuma)" /home/benoit/bb-homelab/storage/scripts/appdata-backup.sh uptime-kuma bb-homelab-uptime-kuma /app/data >> /home/benoit/backups/uptime-kuma/backup.log 2>&1
   20 3 * * * mkdir -p /home/benoit/backups/jellyfin && KUMA_PUSH_URL="$(cat /home/benoit/.config/bb-homelab/kuma-push-jellyfin)" /home/benoit/bb-homelab/storage/scripts/appdata-backup.sh jellyfin bb-homelab-jellyfin /config >> /home/benoit/backups/jellyfin/backup.log 2>&1
   25 3 * * * mkdir -p /home/benoit/backups/popcorntv && KUMA_PUSH_URL="$(cat /home/benoit/.config/bb-homelab/kuma-push-popcorntv)" /home/benoit/bb-homelab/storage/scripts/appdata-backup.sh popcorntv bb-homelab-popcorntv /app/data >> /home/benoit/backups/popcorntv/backup.log 2>&1
   ```

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
Pour une archive copiée sur le PC, la renvoyer d'abord sur
le Pi avec `scp`.

Après une restauration Caddy, la CA est identique : aucun client n'a à
refaire confiance. Restaurer Caddy en dernier si plusieurs services sont
concernés, car c'est lui qui expose les autres.

Couper Caddy coupe aussi l'accès aux autres services : prévoir la
restauration depuis une session SSH Tailscale, qui ne passe pas par Caddy.
