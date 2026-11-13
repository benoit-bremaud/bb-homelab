# Sauvegarde et restauration d'Immich

Immich garde la seule copie vivante des captures une fois la pellicule du
téléphone vidée : ce document décrit le dump nocturne de la base, la copie
miroir vers le portable de la maison et la restauration (issue #224,
[ADR 0010](../../docs/decisions/0010-immich-screenshot-source.md)).

## Principe

| Quoi | Où | Quand | Rétention |
|---|---|---|---|
| Dump Postgres (`pg_dump`, gzip, commande officielle d'Immich) | `/mnt/appdata/immich/db-dumps/` sur le Pi | 03:30 (cron du Pi) | 7 dumps |
| Originaux (`upload`, `library`, `profile`) et dumps intégrés d'Immich (`backups`) | `/mnt/appdata/immich/library/` sur le Pi | en continu | corbeille Immich ≥ 30 jours |
| Miroir des deux lignes ci-dessus | `~/bb-homelab-immich/current/` sur le portable de la maison | 04:30 (timer du portable) | fichier supprimé sur le Pi gardé 30 jours dans `deleted/<date>/` |

- Le **portable tire** la copie par le Wi-Fi de la maison. Le Pi n'a aucun
  accès au portable.
- La clé SSH du portable est **limitée à la lecture** de
  `/mnt/appdata/immich` par `rrsync -ro`. Elle ne peut ni écrire ni ouvrir
  de shell.
- `thumbs/` et `encoded-video/` ne sont pas copiés : Immich les régénère.
- Le dump n'envoie son signal à Uptime Kuma (sonde Push `backup-immich`,
  26 h) qu'en cas de succès. Un échec de la copie déclenche une
  notification sur le bureau du portable.

## Installation sur le Pi (une fois)

```bash
sudo mkdir -p /mnt/appdata/immich/db-dumps
sudo chown benoit:benoit /mnt/appdata/immich/db-dumps
chmod 700 /mnt/appdata/immich/db-dumps
```

Créer la sonde Push `backup-immich` dans Uptime Kuma (intervalle 93600 s,
comme les autres sauvegardes), puis ajouter au crontab de `benoit`
(`crontab -e`) :

```text
30 3 * * * KUMA_PUSH_URL='<URL Push de la sonde>' $HOME/bb-homelab/services/immich/scripts/db-dump.sh >> $HOME/backups/immich-db-dump.log 2>&1
```

## Installation sur le portable de la maison (une fois)

1. Cloner le dépôt dans `~/bb-homelab` et créer une clé dédiée :

   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/bb-homelab-immich-pull -C "immich-pull-$(hostname)-2026"
   ```

2. Sur le Pi, ajouter la clé publique à `~/.ssh/authorized_keys` de
   `benoit`, précédée de la restriction :

   ```text
   command="/usr/bin/rrsync -ro /mnt/appdata/immich",restrict ssh-ed25519 AAAA… immich-pull-<portable>-2026
   ```

3. Sur le portable, `~/.ssh/config` :

   ```text
   Host bb-homelab.local
     User benoit
     IdentityFile ~/.ssh/bb-homelab-immich-pull
     IdentitiesOnly yes
   ```

4. Activer le timer :

   ```bash
   mkdir -p ~/.config/systemd/user
   for u in bb-homelab-immich-pull.service bb-homelab-immich-pull.timer bb-homelab-immich-pull-failed.service; do
     ln -sf ~/bb-homelab/storage/systemd/$u ~/.config/systemd/user/
   done
   systemctl --user daemon-reload
   systemctl --user enable --now bb-homelab-immich-pull.timer
   loginctl enable-linger "$USER"
   ```

   `enable-linger` fait tourner le timer même quand personne n'est connecté.

## Vérification

```bash
systemctl --user start bb-homelab-immich-pull.service
journalctl --user -u bb-homelab-immich-pull.service -n 20
ls ~/bb-homelab-immich/current/library/upload ~/bb-homelab-immich/current/db-dumps
```

Tant que cette vérification n'a pas réussi, ne rien supprimer du téléphone
([diagramme d'activité](../../docs/architecture/diagrams/immich/03-activity.md)).

## Restauration

Test à faire une fois avant de vider la pellicule, puis après chaque mise à
jour majeure d'Immich.

1. Arrêter Immich sur le Pi : `docker compose down` dans `services/immich/`.
2. Recopier les originaux depuis le portable vers
   `/mnt/appdata/immich/library/` (ou les garder s'ils sont intacts).
3. Repartir d'une base vide et charger le dump :

   ```bash
   sudo mv /mnt/appdata/immich/postgres /mnt/appdata/immich/postgres.old
   sudo mkdir /mnt/appdata/immich/postgres
   docker compose up -d database
   gunzip -c /mnt/appdata/immich/db-dumps/immich-db-<date>.sql.gz \
     | sed "s/SELECT pg_catalog.set_config('search_path', '', false);/SELECT pg_catalog.set_config('search_path', 'public, pg_catalog', true);/g" \
     | docker exec -i bb-homelab-immich-postgres psql --dbname=immich --username=postgres --single-transaction --set ON_ERROR_STOP=on
   docker compose up -d
   ```

   La substitution `sed` vient de la procédure officielle d'Immich
   (<https://docs.immich.app/administration/backup-and-restore>).

4. Vérifier dans le navigateur que les captures et leurs albums sont là,
   puis supprimer `postgres.old`.
