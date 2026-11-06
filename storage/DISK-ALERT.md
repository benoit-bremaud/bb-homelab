# Alerte de remplissage des disques

Une tâche cron vérifie toutes les 15 minutes l'occupation de la carte SD
(`/`) et du disque des données (`/mnt/appdata`), et alerte par Uptime Kuma
dès que l'espace ou les inodes atteignent 80 % (issue #202).

## Principe

Le script [`scripts/disk-usage-check.sh`](scripts/disk-usage-check.sh)
envoie au moniteur Push `disk-usage` un signal `up` tant que chaque point de
montage est monté et sous le seuil, et un signal `down` sinon. Le message
`down` nomme le disque en cause (par exemple `-:83pct` pour `/`). Un cron
arrêté n'envoie plus rien : le moniteur passe aussi DOWN.

Diagramme : [01-activity.md](../docs/architecture/diagrams/disk-alert/01-activity.md).

## Ce qui n'est pas couvert

Uptime Kuma tourne sur le même Pi, avec ses données sur `/mnt/appdata`. Un
Pi éteint ou un HDD absent au démarrage arrêtent donc Kuma lui-même, et
personne n'alerte. Ces cas relèvent du veilleur externe (couche 2 de
l'[ADR 0004](../docs/decisions/0004-monitoring-architecture.md), pas encore
en place). Un HDD décroché à chaud peut aussi rester monté avec des erreurs
d'entrée-sortie : ce cas n'est pas détecté.

## Installation sur le Pi (une fois)

Précondition : `df -h /` sous 80 %. Sinon le moniteur reste DOWN dès
l'installation et masque toute autre panne (Kuma n'alerte qu'au passage à
DOWN).

1. Dans Uptime Kuma, créer un moniteur **Push** `disk-usage`, intervalle
   `2700` s (un passage manqué toléré, plus 15 min de marge : la sauvegarde
   de Kuma le met en pause à 03:15), 0 retry, notification
   `BB Infra Alerts`.
2. Enregistrer son URL hors de git, sans la partie après `?` :

   ```bash
   install -d -m 700 ~/.config/bb-homelab
   (umask 077; printf '%s' '<URL push sans ?status=…>' > ~/.config/bb-homelab/kuma-push-disk-usage)
   ```

3. Lancer le script une fois à la main : le moniteur doit passer UP.

   ```bash
   KUMA_PUSH_URL="$(cat ~/.config/bb-homelab/kuma-push-disk-usage)" ~/bb-homelab/storage/scripts/disk-usage-check.sh; echo "exit $?"
   ```

4. Ajouter à `crontab -e` :

   ```cron
   */15 * * * * mkdir -p /home/benoit/.cache && KUMA_PUSH_URL="$(cat /home/benoit/.config/bb-homelab/kuma-push-disk-usage)" /home/benoit/bb-homelab/storage/scripts/disk-usage-check.sh >> /home/benoit/.cache/disk-usage-check.log 2>&1
   ```

## Tester l'alerte

1. Seuil bas, sans URL : le script doit sortir en erreur avec une ligne
   `FAIL`.

   ```bash
   THRESHOLD=10 ~/bb-homelab/storage/scripts/disk-usage-check.sh; echo "exit $?"
   ```

2. Le même appel avec `KUMA_PUSH_URL` : le moniteur passe DOWN, le message
   Telegram nomme le disque. Le passage suivant du cron le remet UP.
3. Cron arrêté : mettre la ligne en commentaire plus de 45 minutes, le
   moniteur passe DOWN.

## Quand l'alerte part

Le journal ne contient que les échecs :

```bash
tail -n 5 ~/.cache/disk-usage-check.log
```

- `not a mount point` : le HDD est démonté, pas plein (voir
  [LAYOUT.md](LAYOUT.md)).
- `% space` ou `% inodes` au-dessus du seuil : libérer de la place
  (`docker system df`, `journalctl --disk-usage`).
- `no KUMA_PUSH_URL` : le fichier d'URL est absent ou vide
  (`ls -l ~/.config/bb-homelab/kuma-push-disk-usage`).
- Journal vide et moniteur DOWN : le cron ne tourne plus (`crontab -l`).

## Réglages

- `THRESHOLD` : seuil d'alerte en pourcentage (entier de 1 à 99), 80 par
  défaut ; l'alerte part dès que l'occupation l'atteint. 80 % est le seuil du
  risque R3 de l'[audit de sécurité](../docs/security/AUDIT.md).
- Arguments : les points de montage à vérifier, `/ /mnt/appdata` par défaut.
