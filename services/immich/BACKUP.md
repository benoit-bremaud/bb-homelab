# Sauvegarde et restauration d'Immich

Immich garde la seule copie vivante des captures une fois la pellicule du
téléphone vidée : ce document décrit le dump nocturne de la base, la copie
miroir vers le portable de la maison et la restauration (issue #224,
[ADR 0010](../../docs/decisions/0010-immich-screenshot-source.md)).

## Principe

| Quoi | Où | Quand | Rétention |
|---|---|---|---|
| Dump Postgres (`pg_dumpall`, gzip, même commande que la procédure d'Immich) | `/mnt/appdata/immich/db-dumps/` sur le Pi | 03:30 (cron du Pi) | 7 dumps |
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
  notification sur le bureau du portable, **seulement si une session
  graphique est ouverte** : le timer tourne aussi sans session
  (`enable-linger`) et son échec passe alors inaperçu. Contrôler le journal
  du timer chaque semaine tant qu'une sonde côté Pi n'existe pas (issue de
  suivi, ADR 0010).

## Installation sur le Pi (une fois)

```bash
sudo mkdir -p /mnt/appdata/immich/db-dumps
sudo chown benoit:benoit /mnt/appdata/immich/db-dumps
chmod 700 /mnt/appdata/immich/db-dumps
```

Créer la sonde Push `backup-immich` dans Uptime Kuma (intervalle 93600 s,
essais `0`, notification `BB Infra Alerts`, comme les autres
sauvegardes). Ranger son URL hors de git, lisible par `benoit` seul :

```bash
install -d -m 700 ~/.config/bb-homelab
(umask 077; printf '%s' '<URL push>' > ~/.config/bb-homelab/kuma-push-immich)
```

Puis ajouter au crontab de `benoit` (`crontab -e`) :

```text
30 3 * * * mkdir -p /home/benoit/backups && KUMA_PUSH_URL="$(cat /home/benoit/.config/bb-homelab/kuma-push-immich)" /home/benoit/bb-homelab/services/immich/scripts/db-dump.sh >> /home/benoit/backups/immich-db-dump.log 2>&1
```

## Installation sur le portable de la maison (une fois)

1. Cloner le dépôt dans `~/bb-homelab` et créer une clé dédiée, sans
   phrase de passe : le timer tourne sans personne pour la saisir, et la
   restriction `rrsync -ro` de l'étape 2 limite la clé à la lecture.

   ```bash
   ssh-keygen -t ed25519 -N '' -f ~/.ssh/bb-homelab-immich-pull -C "immich-pull-$(hostname)-2026"
   ```

2. Sur le Pi, ajouter la clé publique à `~/.ssh/authorized_keys` de
   `benoit`, précédée de la restriction. `from=` n'accepte la clé que
   depuis l'IP du portable sur le réseau de la maison (à fixer dans la box) :

   ```text
   from="<IP du portable>",command="/usr/bin/rrsync -ro /mnt/appdata/immich",restrict ssh-ed25519 AAAA… immich-pull-<portable>-2026
   ```

3. Sur le portable, `~/.ssh/config` :

   ```text
   Host bb-homelab.local
     User benoit
     IdentityFile ~/.ssh/bb-homelab-immich-pull
     IdentitiesOnly yes
   ```

4. Enregistrer la clé d'hôte du Pi (le script refuse toute question
   interactive). Comparer l'empreinte affichée par la première commande, sur
   le portable, avec celle de la seconde, lancée sur le Pi, avant de
   répondre `yes` :

   ```bash
   ssh -o IdentitiesOnly=yes bb-homelab.local true    # sur le portable ; rrsync refuse la commande, c'est normal
   ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub   # sur le Pi
   ```

5. Activer le timer (`RestartMode=direct` demande systemd 254 ou plus :
   plus ancien, chaque nouvel essai déclenche aussi l'alerte) :

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
([diagramme d'activité](../../docs/architecture/diagrams/immich/07-activity-free-phone-space.md)).

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
   docker compose up -d --wait database
   gunzip -c /mnt/appdata/immich/db-dumps/immich-db-<date>.sql.gz \
     | sed "s/SELECT pg_catalog.set_config('search_path', '', false);/SELECT pg_catalog.set_config('search_path', 'public, pg_catalog', true);/g" \
     | docker exec -i bb-homelab-immich-postgres psql --dbname=postgres --username=postgres
   docker compose up -d
   ```

   `--wait` attend que Postgres ait fini sa première initialisation. Le
   dump `pg_dumpall` recrée lui-même la base `immich` : on se connecte donc
   à `postgres`, sans `--single-transaction` (`DROP DATABASE` ne passe pas
   dans une transaction).

   La substitution `sed` vient de la procédure officielle d'Immich
   (<https://docs.immich.app/administration/backup-and-restore>).

4. Vérifier dans le navigateur que les captures et leurs albums sont là,
   puis supprimer `postgres.old`.
