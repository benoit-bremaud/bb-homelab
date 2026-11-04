# ADR 0008 — Stockage Docker sur le disque des données

- **Status**: Accepted
- **Date**: 2026-11-04

## Context

Le pentest du 2026-11-04 (finding H11, issue #202) a relevé une carte SD
à 83 %, au-dessus du seuil de 80 % de l'audit (risque R3 de
`docs/security/AUDIT.md`). Les données des services sont déjà sur le HDD
`/mnt/appdata`, mais le stockage interne de Docker est resté sur la SD :
13,7 Go d'images, dont 14 sur 15 en service. Un nettoyage ne libère
qu'environ 230 Mo.

Docker 29 utilise le stockage d'images de containerd : les images sont
dans `/var/lib/containerd`, les conteneurs et volumes dans
`/var/lib/docker`. Docker attend déjà le HDD au démarrage
(`RequiresMountsFor=/mnt/appdata`).

## Decision

Déplacer les deux dossiers sur le HDD : `root = "/mnt/appdata/containerd"`
dans `/etc/containerd/config.toml` et `"data-root": "/mnt/appdata/docker"`
dans `/etc/docker/daemon.json`. containerd reçoit lui aussi
`RequiresMountsFor=/mnt/appdata`. Procédure, contrôles et retour arrière :
[storage/DOCKER-STORAGE-MOVE.md](../../storage/DOCKER-STORAGE-MOVE.md).

## Consequences

- Positives : environ 14 Go libérés sur la SD, qui repasse nettement sous
  80 % ; moins d'écritures sur la SD (usure) ; place pour les images
  futures.
- Négatives : sans le HDD, plus aucun conteneur ne démarre, y compris
  ceux sans données sur le HDD ; une panne du HDD ou de son boîtier USB
  (#168) arrête toute la pile. Le vol ou la perte du HDD concerne
  désormais aussi les images (#206).
- Coupure de quelques minutes à l'exécution, en présence du propriétaire.

## Alternatives considered

Notes de 0 à 5, poids entre parenthèses, total sur 500 :

| Option | Place (35) | Risque (30) | Effort (20) | Cohérence (15) | Total | Raison |
|---|---|---|---|---|---|---|
| Déplacer le stockage Docker sur le HDD | 5 | 3 | 3 | 4 | 385 | Retenue |
| Nettoyage seul (cache, volume orphelin, anciens paquets) | 1 | 5 | 5 | 3 | 330 | Moins de 1 Go libéré, la SD remonte en quelques jours |
| Démarrer le Pi sur SSD ou HDD (#29) | 5 | 1 | 1 | 4 | 285 | Migration complète et redémarrage ; reste ouverte à plus long terme |

Sensibilité : en prenant des points sur la place pour les donner au
risque, le nettoyage passe devant dès que la place pèse 25 ou moins
(risque 40 ou plus) ; en les prenant sur l'effort, le déplacement reste
devant (385 contre 330). Le choix tient tant que libérer durablement la SD
reste le critère principal, ce qui est l'objet de l'issue.

## Refs

- Issue #202, PR #212 (alerte de remplissage)
- ADR 0004 (supervision), issues #29, #168, #206
- `storage/DOCKER-STORAGE-MOVE.md`, `storage/LAYOUT.md`
