# Copie hors du Pi — rapatriement nocturne des sauvegardes

Les sauvegardes nocturnes de n8n et Vaultwarden sont écrites sur la carte SD
du Pi. Si le Pi meurt ou disparaît, elles partent avec lui. Ce dispositif en
garde une seconde copie sur le PC de développement (issue #133, diagrammes
dans [docs/architecture/diagrams/backup/](../docs/architecture/diagrams/backup/01-sequence.md)).

## Principe

- C'est le **PC qui tire** les archives par `rsync` sur SSH. Le Pi n'a aucun
  accès au PC : un Pi compromis ne peut ni lire ni effacer cette copie.
- Pas de `--delete` : les archives supprimées par la rotation du Pi restent
  sur le PC, qui garde un historique plus long.
- Fichiers en `600`, dossiers en `700` : les archives Vaultwarden contiennent
  la base chiffrée et `rsa_key.pem`.
- Le timer tourne à 04:00 ; s'il était éteint, le PC rattrape la copie à son
  prochain démarrage (`Persistent=true`).

Ce n'est pas une copie hors site : le PC est dans la même maison. La copie
hors site chiffrée reste l'objet de l'issue #19.

## Fichiers

| Fichier | Rôle |
|---|---|
| [`scripts/pull-backups.sh`](scripts/pull-backups.sh) | Copie `~/backups/n8n/` et `~/vaultwarden-backups/` du Pi vers `~/Documents/02_personal/bb-homelab-backups/{n8n,vaultwarden}/` |
| [`systemd/bb-homelab-backup-pull.service`](systemd/bb-homelab-backup-pull.service) | Lance le script une fois |
| [`systemd/bb-homelab-backup-pull.timer`](systemd/bb-homelab-backup-pull.timer) | Chaque jour à 04:00, avec rattrapage |

## Installation sur le PC (une fois)

Prérequis : `ssh benoit@bb-homelab` fonctionne sans mot de passe (clé SSH).

```bash
mkdir -p ~/.config/systemd/user
ln -sf ~/Documents/02_personal/bb-homelab/storage/systemd/bb-homelab-backup-pull.service ~/.config/systemd/user/
ln -sf ~/Documents/02_personal/bb-homelab/storage/systemd/bb-homelab-backup-pull.timer ~/.config/systemd/user/
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
