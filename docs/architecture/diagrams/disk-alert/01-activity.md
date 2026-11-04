# Diagramme d'activité — vérification du remplissage des disques

> **Fonctionnalité** : issue #202 — alerte avant que la carte SD soit pleine
> **Décisions capturées** : seuil de 80 % (espace et inodes), signal `down`
> qui nomme le disque, absence de signal pour un cron arrêté, disque démonté
> = échec
> **ADR liés** : [0004](../../../decisions/0004-monitoring-architecture.md)
> (un Pi éteint relève du veilleur externe)

## Contexte

La tâche cron lance `storage/scripts/disk-usage-check.sh` toutes les
15 minutes. Uptime Kuma tourne sur le même Pi.

## Diagramme

```mermaid
flowchart TD
  subgraph Pi["Pi : cron et script"]
    start([cron, toutes les 15 min]) --> loop{point de montage suivant ?}
    loop -- oui --> mounted{monté ?}
    mounted -- non --> fail[échec noté dans le journal]
    mounted -- oui --> df{df répond ?}
    df -- non --> abort([arrêt en erreur, aucun signal])
    df -- oui --> usage{espace et inodes sous le seuil ?}
    usage -- non --> fail
    usage -- oui --> loop
    fail --> loop
    loop -- non --> anyfail{un échec ?}
    anyfail -- oui --> down[signal down, disque en cause]
    anyfail -- non --> up[signal up]
    down --> endfail([sortie 1])
    up --> endok([sortie 0])
  end
  subgraph Kuma["Uptime Kuma"]
    k1[moniteur disk-usage]
    k2[DOWN : alerte Telegram]
    k3[45 min sans signal]
  end
  down -.-> k2
  up -.-> k1
  abort -.-> k3
  k3 -.-> k2
```

## Notes

- Retour sous le seuil : le signal `up` reprend, Kuma envoie « rétabli ».
