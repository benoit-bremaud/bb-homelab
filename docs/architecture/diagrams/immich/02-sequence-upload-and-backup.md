# Diagramme de séquence — envoi d'une capture, OCR et sauvegarde nocturne

> **Fonctionnalité** : issue #224 — Immich, source des captures d'écran
> **ADR liés** : ADR 0010, ADR 0004
> **Décisions capturées** : envoi à la maison en Wi-Fi seulement, OCR dès
> l'envoi, dump Postgres avant la copie des fichiers, signal « réussi »
> seulement en cas de succès, copie tirée par le portable de la maison

## Contexte

Une capture prise dans la journée doit arriver sur le Pi, recevoir son
texte OCR, puis exister en deux exemplaires (Pi et portable de la maison)
avant qu'on la supprime du téléphone. Le tri hebdomadaire par
screenshot-triage vient ensuite ; il est décrit dans son propre dépôt.

## Diagramme

```mermaid
sequenceDiagram
  autonumber
  actor owner as Propriétaire
  participant app as App Immich (téléphone)
  participant srv as immich-server (Pi)
  participant ml as immich-machine-learning
  participant pg as Postgres
  participant cron as cron (Pi)
  participant kuma as Uptime Kuma
  participant ssh as sshd + rrsync -ro (Pi)
  participant lap as Timer de copie (portable)

  owner->>app: prend une capture
  alt téléphone sur le Wi-Fi de la maison
    app->>srv: POST /api/assets (album Captures)
    srv->>pg: enregistre l'asset
    srv-->>app: 201 créé
    srv->>ml: OCR de l'asset, après la vignette (concurrence 1)
    ml-->>srv: texte OCR
    srv->>pg: stocke le texte
  else hors de la maison
    Note over app: envoi différé au retour en Wi-Fi
  end

  cron->>pg: pg_dumpall | gzip vers db-dumps
  alt dump réussi
    cron->>kuma: push status=up
  else échec
    Note over kuma: aucun signal → sonde DOWN, alerte
  end

  lap->>ssh: rsync upload, library, profile, backups, db-dumps
  ssh-->>lap: fichiers en lecture seule
  Note over lap: fichiers supprimés sur le Pi → dossier daté, purge à 30 j
```
