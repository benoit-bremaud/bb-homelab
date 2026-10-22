# Diagramme de séquence — sauvegarde nocturne, alerte et copie hors du Pi

> **Fonctionnalité** : issue #133 — alerte en cas d'échec + copie hors du Pi
> **ADR liés** : ADR 0004 (architecture de supervision)
> **Décisions capturées** : signal « réussi » uniquement en cas de succès,
> alerte par absence de signal, copie tirée depuis le PC (le Pi n'a aucun
> accès au PC)

## Contexte

Du 2026-08-24 au 2026-10-22, les sauvegardes n8n et Vaultwarden ont échoué
chaque nuit sans que personne ne le sache, et leurs archives ne vivaient que
sur la carte SD du Pi. Ce diagramme montre une nuit normale et une nuit en
échec avec le nouveau dispositif.

Il ne couvre pas la copie hors site chiffrée (issue #19) ni la sauvegarde de
Caddy et d'Uptime Kuma (issue de suivi).

## Diagramme

```mermaid
sequenceDiagram
  autonumber
  participant cron as cron (Pi)
  participant bk as backup.sh
  participant ct as conteneur (n8n / Vaultwarden)
  participant sd as ~/backups (SD du Pi)
  participant kuma as Uptime Kuma (sonde Push)
  participant tg as Telegram bb-homelab-alerts
  participant pc as timer systemd (PC)

  cron->>bk: 03:00 n8n · 03:05 Vaultwarden
  bk->>ct: conteneur en marche ?
  alt sauvegarde réussie
    ct-->>bk: instantané cohérent
    bk->>sd: archive .tar.gz (chmod 600) + rotation
    bk->>kuma: GET KUMA_PUSH_URL?status=up
  else échec (conteneur arrêté, disque absent…)
    bk-->>cron: code de sortie ≠ 0, rien n'est envoyé
    Note over kuma: aucun signal depuis 25 h → sonde DOWN
    kuma->>tg: alerte « sauvegarde n8n / Vaultwarden manquante »
  end
  pc->>sd: rsync (SSH, clé du PC) vers ~/Documents/02_personal/bb-homelab-backups
  Note over pc: tourne au réveil du PC si la nuit a été manquée (Persistent=true)
  Note over pc: en cas d'échec, notification locale sur le PC (OnFailure)
```

## Notes

- Le Pi pousse vers Uptime Kuma, qui tourne sur le même Pi : si le Pi entier
  tombe, aucune de ces sondes ne parle. Ce cas relève de la supervision
  externe prévue par l'ADR 0004, pas de ce dispositif.
- L'URL de la sonde contient un jeton : elle reste dans un `.env` ignoré par
  git sur le Pi.
