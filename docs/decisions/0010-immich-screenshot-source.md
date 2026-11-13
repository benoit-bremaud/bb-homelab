# ADR 0010 — Immich, source des captures d'écran du téléphone

- **Status**: Accepted
- **Date**: 2026-11-13

## Context

Le pipeline screenshot-triage (dépôt `screenshot-triage`, ADR-0001) trie
chaque semaine les captures d'écran du téléphone Android. Le propriétaire a
retenu la sauvegarde automatique de l'app mobile Immich comme source
(MCDA 430 contre Syncthing 370 et USB 255, 2026-11-13). Immich devient à la
fois la source, l'archive privée et la recherche (issue #224).

Contraintes :

- Tout tourne à la maison : sur le Pi ou sur le portable de la maison, qui
  reste allumé en permanence. Pas de cloud ni de VPS.
- Vie privée : seul l'album Captures d'écran est sauvegardé, jamais toute
  la pellicule.
- La pellicule du téléphone sera vidée : Immich devient la seule copie
  vivante des captures.
- screenshot-triage #3 lit le texte OCR d'Immich (`getAssetOcr`) avant
  d'ouvrir une image : c'est ce qui permet d'écarter une capture
  personnelle sans la lire.
- L'app mobile Immich gère mal les certificats auto-signés et les CA
  privées : l'envoi échoue souvent. La documentation d'Immich recommande
  un VPN.
- Android ne résout pas `*.bb-homelab.local` :
  `services/vaultwarden/CLIENTS.md`.

## Decision

1. **Hôte : le Pi.** Il est toujours allumé et déjà couvert par les
   sauvegardes, la copie hors du Pi et Uptime Kuma. Le portable de la
   maison reste une réserve pour le calcul OCR, qu'Immich sait déporter
   vers une autre machine, si le Pi se révèle trop lent.
2. **Stockage : `/mnt/appdata/immich`** sur le Disque A, en bind mounts
   `create_host_path: false` : le conteneur refuse de démarrer si le disque
   manque, plutôt que d'écrire sur la carte SD. Postgres tourne en mode
   disque dur (`DB_STORAGE_TYPE=HDD`).
3. **Apprentissage automatique : OCR seul, dès l'envoi.** Le conteneur ML
   ne charge que les modèles OCR. La recherche intelligente (CLIP) et la
   reconnaissance des visages sont désactivées. Immich v3.4.1 n'a pas de
   plage horaire pour l'OCR : il le lance après la vignette de chaque
   envoi. Les tâches tournent avec une concurrence de 1, et les modèles
   sont déchargés après 5 min d'inactivité. Le choix initial « la nuit »
   reposait sur un réglage qui n'existe pas ; le propriétaire a retenu
   l'OCR dès l'envoi le 2026-11-13 (440, contre une pause de jour par cron
   360 et un lancement manuel 330). La recherche complète (phase C) fera l'objet d'une issue
   de suivi, ouverte une fois la charge du Pi mesurée.
4. **Accès :**
   - **Téléphone :** il envoie seulement, à la maison et en Wi-Fi, par le
     tunnel Tailscale déjà installé, à l'adresse `http://bb-homelab:2283`.
     Le port est publié sur `127.0.0.1` et sur l'IP tailnet seulement
     (ADR 0007, même modèle que Jellyfin). Le trafic est chiffré par
     WireGuard.
   - **PC et screenshot-triage :** ils passent par Caddy en HTTPS, sur un
     réseau proxy dédié (ADR 0009).
5. **Sauvegardes :**
   - Postgres : un dump `pg_dumpall` chaque nuit dans `db-dumps`, avec une
     sonde Push Uptime Kuma.
   - Photos : les dossiers `upload`, `library`, `profile` et `backups`,
     plus `db-dumps`, sont tirés chaque nuit par rsync incrémental vers le portable de la maison.
     `thumbs` et `encoded-video` sont reconstructibles et ne sont pas
     copiés.
   - Rétention : miroir où un fichier supprimé sur le Pi part dans un
     dossier daté, purgé après 30 jours.
   - La corbeille Immich est réglée à 30 jours au moins.
6. **Suppression sur le téléphone :** « libérer de l'espace » ne
   s'applique qu'aux captures de plus de 2 jours, une fois le premier test
   de restauration réussi et la copie sur le portable vérifiée.
7. **Clé d'API de screenshot-triage :** droits limités à ce que le
   pipeline appelle, nom daté, rappel de rotation, rangée dans le
   gestionnaire de mots de passe. La permission de suppression permet une
   purge définitive (`force`) : la corbeille et la copie du portable sont
   le filet de sécurité.

Matrices MCDA validées par le propriétaire le 2026-11-13 (poids /100,
notes 0–5). Six totaux mal additionnés à la présentation ont été corrigés à
la revue ; aucun gagnant ne change :

| Hôte | Dispo 30 | Cohérence 25 | OCR 20 | Place 15 | Simple 10 | Total /500 |
|---|---|---|---|---|---|---|
| A. Tout sur le Pi | 5 | 5 | 3 | 4 | 5 | **445** |
| B. Pi + OCR sur le portable | 4 | 4 | 5 | 4 | 2 | 400 |
| C. Tout sur le portable | 2 | 2 | 5 | 2 | 3 | 270 |

| Stockage | Sûreté 35 | SD 25 | Simple 25 | Migration 15 | Total /500 |
|---|---|---|---|---|---|
| A. `/mnt/appdata` | 4 | 5 | 5 | 4 | **450** |
| B. Bibliothèque sur `/mnt/archive` | 4 | 5 | 2 | 3 | 360 |
| C. Volumes Docker | 2 | 5 | 4 | 2 | 325 |

| OCR pour #3 | Débloque 35 | Charge 25 | Simple 20 | ADR 20 | Total /500 |
|---|---|---|---|---|---|
| a. ML OCR seul (prévu la nuit, voir point 3) | 5 | 3 | 3 | 5 | **410** |
| b. Sans ML, #3 attend | 2 | 5 | 5 | 5 | 395 |
| c. OCR hors Immich | 4 | 4 | 2 | 1 | 300 |

| Accès | Sécurité 35 | Simple 25 | Cohérence 25 | Nom privé 15 | Total /500 |
|---|---|---|---|---|---|
| A. Téléphone par le tunnel, PC en HTTPS | 4 | 5 | 5 | 5 | **465** |
| C. Tunnel seul, même sur le PC | 3 | 5 | 3 | 5 | 380 |
| B. HTTPS `ts.net` partout | 5 | 2 | 3 | 2 | 330 |

| Sauvegarde | Restauration 40 | Cohérence 30 | Effort 30 | Total /500 |
|---|---|---|---|---|
| A. Dump + rsync + sonde + copie hors du Pi | 5 | 5 | 4 | **470** |
| B. Sans copie hors du Pi | 3 | 4 | 5 | 390 |
| C. Dumps intégrés d'Immich seuls | 3 | 2 | 5 | 330 |

| Rétention de la copie | Vie privée 35 | Récupération 35 | Simple 30 | Total /500 |
|---|---|---|---|---|
| A. Miroir, suppression différée 30 j | 4 | 4 | 3 | **370** |
| B. Garder pour toujours | 1 | 5 | 5 | 360 |
| C. Miroir strict | 5 | 1 | 5 | 360 |

| Cible de la copie | Régularité 40 | Effort 25 | Cohérence 20 | Place 15 | Total /500 |
|---|---|---|---|---|---|
| A. Portable de la maison | 5 | 3 | 3 | 3 | **380** |
| C. Les deux | 5 | 2 | 3 | 2 | 340 |
| B. PC de travail (XPS) | 2 | 5 | 5 | 2 | 335 |

Sensibilité des matrices serrées :

- Stockage, Accès, Sauvegarde : l'option retenue égale ou dépasse les
  autres sur presque chaque critère ; aucun poids raisonnable ne l'inverse.
- OCR : b passe devant (425 contre 390) si la charge pèse 35 et le
  déblocage de #3 25. Le choix tient tant que débloquer #3 compte plus que
  la charge du Pi.
- Rétention : B passe devant (380 contre 360) si la simplicité pèse 40.
  Le choix tient tant que la vie privée et la récupération comptent plus.
- Cible : A domine C. B ne passe devant (380 contre 350) que si l'effort
  pèse plus que la régularité (40 contre 25).

## Consequences

- Le port 2283 du Pi est publié sur l'IP tailnet : deux entrées pour un
  même service (port direct et Caddy). Le retirer revient à supprimer une
  ligne de `ports`.
- Le portable de la maison n'est pas sur le tailnet. Il tire la copie par
  le réseau local de la maison. Le SSH du Pi écoute sur toutes ses
  interfaces (vérifié le 2026-11-13). La clé du portable est limitée à la
  lecture des dossiers d'Immich (`rrsync -ro`) et à l'IP du portable
  (`from=`). Le résolveur mDNS du Pi (avahi sur `eth0`, #205) fournit le
  nom `bb-homelab.local` au portable.
- **#141 doit garder ce chemin** : restreindre SSH au tailnet
  (`SSH_UFW_SCOPE=tailscale`) couperait la seule copie hors du Pi. La règle
  pare-feu doit garder `ufw allow from <IP du portable> to any port 22
  proto tcp` (`docs/security/AUDIT.md`, R13).
- Un échec de la copie n'alerte que si une session graphique est ouverte
  sur le portable (`notify-send`). Une sonde côté Pi qui vérifie la
  fraîcheur de la copie fera l'objet d'une issue de suivi ; en attendant,
  le journal du timer est contrôlé chaque semaine.
- L'IP tailnet du Pi est désormais écrite dans trois compose (Caddy,
  Jellyfin, Immich) : la procédure de l'ADR 0007 en cas de changement
  d'IP s'applique aussi à `services/immich/docker-compose.yml`.
- **Déploiement suspendu** : Trivy trouve des failles critiques corrigées
  en amont dans les paquets des images serveur, ML et Postgres v3.4.1. Le
  propriétaire a choisi le 2026-11-13 d'attendre des images d'Immich
  corrigées plutôt que de poser des exceptions (470, contre exceptions
  440 et reconstruction locale 430). screenshot-triage #3 attend ce
  déploiement.
- Postgres 14 arrive en fin de vie en novembre 2026 : la montée de version
  suivra Immich (issue de suivi).
- L'app mobile et le serveur doivent rester compatibles : la mise à jour
  automatique de l'app est coupée, et le serveur est mis à jour en premier.
- Les alertes Kuma dépendent de la liaison sortante du Pi (#237).

## Alternatives considered

Voir les matrices ci-dessus. Syncthing et la copie USB ont été écartés au
choix de la source (débrief screenshot-triage du 2026-11-13).

## Refs

- Issue #224 ; `screenshot-triage` ADR-0001 et issue #3.
- ADR 0002 (Caddy), ADR 0007 (ports publiés), ADR 0008 (stockage Docker),
  ADR 0009 (réseaux proxy par backend).
- Diagrammes : [docs/architecture/diagrams/immich/](../architecture/diagrams/immich/08-deployment.md).
