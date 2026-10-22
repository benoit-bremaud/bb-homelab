# Copie hors du Pi — rapatriement nocturne des sauvegardes

Les sauvegardes nocturnes de n8n et Vaultwarden sont écrites sur la carte SD
du Pi. Si le Pi meurt ou disparaît, elles partent avec lui. Ce dispositif en
garde une seconde copie sur le PC de développement (issue #133, diagrammes
dans [docs/architecture/diagrams/backup/](../docs/architecture/diagrams/backup/01-sequence.md)).

## Principe

- C'est le **PC qui tire** les archives par `rsync` sur SSH (`rsync` ≥ 3.2.5
  côté PC). Le Pi n'a aucun accès au PC : un Pi compromis ne peut ni lire ni
  effacer cette copie, et une archive déjà copiée n'est jamais remplacée
  (`--ignore-existing`). Seuls les `*.tar.gz` et les `*.log` sont copiés.
- Pas de `--delete` : les archives supprimées par la rotation du Pi restent
  sur le PC, qui garde un historique plus long. Il n'y a pas de rétention
  côté PC : le dossier grossit d'environ 450 Ko par nuit, à purger à la main.
- Fichiers en `600`, dossiers en `700` : les archives Vaultwarden contiennent
  la base chiffrée et `rsa_key.pem`.
- Le timer tourne entre 04:00 et 04:10 ; si le PC était éteint, il rattrape
  la copie à son prochain démarrage (`Persistent=true`) et réessaie 5 min
  plus tard si le Pi n'est pas encore joignable (3 tentatives au plus).
- Un échec de copie déclenche une notification sur le bureau du PC
  (`OnFailure`), pour ne pas retomber dans une panne silencieuse.

Ce n'est pas une copie hors site : le PC est dans la même maison. La copie
hors site chiffrée reste l'objet de l'issue #19.

## Fichiers

| Fichier | Rôle |
|---|---|
| [`scripts/pull-backups.sh`](scripts/pull-backups.sh) | Copie `~/backups/n8n/` et `~/vaultwarden-backups/` du Pi vers `~/Documents/02_personal/bb-homelab-backups/{n8n,vaultwarden}/` |
| [`systemd/bb-homelab-backup-pull.service`](systemd/bb-homelab-backup-pull.service) | Lance le script une fois |
| [`systemd/bb-homelab-backup-pull.timer`](systemd/bb-homelab-backup-pull.timer) | Chaque jour entre 04:00 et 04:10, avec rattrapage |
| [`systemd/bb-homelab-backup-pull-failed.service`](systemd/bb-homelab-backup-pull-failed.service) | Notification de bureau si la copie échoue |

## Installation sur le PC (une fois)

Prérequis : `ssh benoit@bb-homelab` fonctionne sans mot de passe (clé SSH).

```bash
mkdir -p ~/.config/systemd/user
ln -sf ~/Documents/02_personal/bb-homelab/storage/systemd/bb-homelab-backup-pull.service ~/.config/systemd/user/
ln -sf ~/Documents/02_personal/bb-homelab/storage/systemd/bb-homelab-backup-pull.timer ~/.config/systemd/user/
ln -sf ~/Documents/02_personal/bb-homelab/storage/systemd/bb-homelab-backup-pull-failed.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now bb-homelab-backup-pull.timer
```

## Vérification

```bash
systemctl --user start bb-homelab-backup-pull.service
journalctl --user -u bb-homelab-backup-pull.service -n 20
ls -l ~/Documents/02_personal/bb-homelab-backups/*/
systemctl --user list-timers bb-homelab-backup-pull.timer
```

## Restauration

Une archive copiée ici se restaure exactement comme sur le Pi : voir
[services/n8n/BACKUP.md](../services/n8n/BACKUP.md) et
[services/vaultwarden/BACKUP.md](../services/vaultwarden/BACKUP.md). La
copier d'abord sur le Pi avec `scp`.
