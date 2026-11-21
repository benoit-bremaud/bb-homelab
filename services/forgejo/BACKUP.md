# Sauvegarde et restauration de Forgejo

Sauvegarde nocturne de tout l'état de Forgejo par le script commun
`appdata-backup.sh`, avec la vérification d'une archive et la restauration
(issue #260,
[ADR 0011](../../docs/decisions/0011-forgejo-git-forge.md)).

## Principe

| Quoi | Où | Quand | Rétention |
| --- | --- | --- | --- |
| `/var/lib/gitea` du conteneur (dépôts git, `data/gitea.db`, `custom/conf/app.ini`, clé d'hôte SSH, pièces jointes) | `~/backups/forgejo/forgejo-AAAA-MM-JJ_HHMMSS.tar.gz` sur le Pi | 03:35 (cron du Pi) | 7 archives |
| Copie des archives | `~/Documents/02_personal/bb-homelab-backups/forgejo/` sur le PC | entre 04:00 et 04:10 ([OFFPI-COPY.md](../../storage/OFFPI-COPY.md)) | sans suppression |

- Le script met le conteneur en pause pendant la copie : la base SQLite et
  les dépôts forment un ensemble cohérent. Forgejo ne répond pas pendant
  ces secondes.
- L'archive contient `app.ini` (jetons internes) et tous les dépôts : elle
  est en `chmod 600` sur le Pi comme sur le PC, ne jamais la copier
  ailleurs en clair.
- `FORGEJO_SECRET_KEY` vit dans `.env`, hors de `/var/lib/gitea` ;
  Forgejo la recopie dans `app.ini`, donc dans l'archive. En garder aussi
  une copie dans le gestionnaire de mots de passe.
- Une exécution réussie envoie un signal à la sonde Push `backup-forgejo`
  d'Uptime Kuma ; un échec n'envoie rien et la sonde alerte.

Fonctionnement détaillé du script :
[storage/APPDATA-BACKUP.md](../../storage/APPDATA-BACKUP.md).

## Installation sur le Pi (une fois)

1. Dans Uptime Kuma, créer la sonde **Push** `backup-forgejo` :
   intervalle `93600` s, 0 essai, notification `BB Infra Alerts`.
2. Ranger son URL hors de git :

   ```bash
   install -d -m 700 ~/.config/bb-homelab
   (umask 077; printf '%s' '<URL push>' > ~/.config/bb-homelab/kuma-push-forgejo)
   ```

3. Ajouter au crontab de `benoit` (`crontab -e`), après Immich (03:30) :

   ```cron
   35 3 * * * mkdir -p /home/benoit/backups/forgejo && KUMA_PUSH_URL="$(cat /home/benoit/.config/bb-homelab/kuma-push-forgejo)" /home/benoit/bb-homelab/storage/scripts/appdata-backup.sh forgejo bb-homelab-forgejo /var/lib/gitea >> /home/benoit/backups/forgejo/backup.log 2>&1
   ```

## Vérifier une archive

```bash
A="$(ls -1t ~/backups/forgejo/*.tar.gz | head -n1)"
T="$(mktemp -d)" && tar -xzf "$A" -C "$T"
sqlite3 "$T/var_lib_gitea/data/gitea.db" 'PRAGMA integrity_check;'   # attendu : ok
ls "$T/var_lib_gitea/git/repositories"                               # un dossier par utilisateur
test -s "$T/var_lib_gitea/custom/conf/app.ini" && echo "app.ini présent"
rm -rf "$T"
```

## Restauration

Précondition : le disque est monté (`mountpoint -q /mnt/appdata`).

```bash
cd ~/bb-homelab/services/forgejo
ARCHIVE=~/backups/forgejo/forgejo-<date>.tar.gz
DEST=/mnt/appdata/forgejo

if mountpoint -q /mnt/appdata && test -d "${DEST}" && test -f "${ARCHIVE}"; then
  docker compose down
  sudo find "${DEST}" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
  sudo tar -xzf "${ARCHIVE}" -C "${DEST}" --strip-components=2 ./var_lib_gitea
  sudo chown -R -h 1000:1000 "${DEST}"
  docker compose up -d
else
  echo "STOP : disque non monté, dossier ou archive absent"
fi
```

- `.env` doit porter la même `FORGEJO_SECRET_KEY` qu'au moment de la
  sauvegarde.
- Pour une archive copiée sur le PC, la renvoyer d'abord sur le Pi avec
  `scp`.
- Après la restauration : ouvrir un dépôt dans le navigateur, puis
  `git ls-remote` en SSH depuis un client. La clé d'hôte SSH est
  restaurée : aucun client ne voit d'alerte.

## Test de restauration

À faire au premier déploiement, avec un dépôt d'essai, puis après chaque
montée de version majeure. Noter la date et le résultat dans
`PROJECT_LOG.md`.

## Limites

- La copie est bornée à 120 secondes (`appdata-backup.sh`). Au-delà, la
  sauvegarde échoue, Forgejo reprend et la sonde Push alerte : passer
  alors à `forgejo dump` ou à une copie par `rsync`.
- Ce n'est pas une copie hors site : le PC est dans la même maison
  (issue #19).
