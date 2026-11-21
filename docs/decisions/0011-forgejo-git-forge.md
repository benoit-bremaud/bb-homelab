# ADR 0011 — Forgejo comme forge git auto-hébergée

- **Status**: Accepted
- **Date**: 2026-11-20

## Context

Les projets personnels sont hébergés sur GitHub. Le propriétaire veut
une forge git qu'il contrôle, sur le Pi, comme alternative à GitHub
pour ces projets (issue #260).

Les briques nécessaires sont en place : Caddy et sa CA interne
(ADR 0002), un réseau proxy par backend et le filtre tailnet
(ADR 0009), la liaison des ports publiés à loopback et au tailnet
(ADR 0007), le HDD `/mnt/appdata` et sa sauvegarde nocturne, les
limites mémoire par service (#256).

Contraintes : un seul utilisateur, un Pi 5 de 8 Go partagé avec les
autres services, aucun accès hors tailnet.

## Decision

Déployer **Forgejo** sous `services/forgejo/`, image **rootless**, avec
ces sous-décisions (matrices MCDA validées par le propriétaire le
2026-11-20, poids /100, notes 0–5, total /500) :

1. **Base SQLite**, dans le dossier de données de Forgejo.

   | Base | Total /500 |
   | --- | --- |
   | A. SQLite | **450** |
   | B. PostgreSQL (conteneur dédié) | 350 |

   Un seul utilisateur : SQLite suffit, sans second conteneur à
   sauvegarder, surveiller et mettre à jour.

2. **Git en HTTPS via Caddy et en SSH sur le tailnet.** Le site
   `git.bb-homelab.local` suit le patron des autres sites (`tls
   internal`, `tailnet_only`, `/api/healthz` ouvert pour Uptime Kuma).
   Le serveur SSH intégré de Forgejo est publié sur
   `100.121.134.61:2222` seulement.

   | Transport | Total /500 |
   | --- | --- |
   | A. HTTPS + SSH intégré sur l'IP tailnet, port 2222 | **455** |
   | B. HTTPS seul | 390 |
   | C. SSH via le sshd de l'hôte (relais) | 370 |

   URL de clone :
   `ssh://git@git.bb-homelab.local:2222/<utilisateur>/<dépôt>.git`.

3. **Ligne LTS, version 15.0.12**, épinglée (fin de support
   2027-07-15).

   | Version | Total /500 |
   | --- | --- |
   | A. LTS 15.0.12 | **470** |
   | B. Stable 17.0.2 (fin de support 2027-01-28) | 375 |

   La ligne stable impose une montée de version majeure tous les trois
   mois ; la LTS n'en demande qu'une par an.

4. **Instance fermée** : inscription désactivée, assistant
   d'installation verrouillé (`INSTALL_LOCK`), compte administrateur
   créé par le propriétaire en ligne de commande. Aucun mot de passe
   ne passe par le dépôt.

5. **Pas de runner Forgejo Actions.** Les contrôles restent locaux
   (règle du propriétaire du 2026-11-07).

Le rôle de Forgejo face à GitHub (miroir, forge principale ou
remplacement) n'est pas tranché ici : il le sera une fois l'instance en
service, dans un nouvel ADR.

## Consequences

**Positive:**

- Une forge git sous contrôle du propriétaire, sans dépendance à un
  service tiers, joignable de tous les appareils du tailnet.
- Un seul conteneur, durci comme les autres (utilisateur non root,
  `cap_drop: [ALL]`, racine en lecture seule, limites mémoire et pids).
- Tout l'état tient dans un dossier, `/mnt/appdata/forgejo`.

**Negative:**

- Un port de plus est publié par Docker, qui contourne UFW (ADR 0007) :
  la liaison à l'IP tailnet est le seul filtre du port 2222.
- Ajouter le site demande de recréer Caddy (ADR 0009), ce qui fait
  tomber toutes les sondes Kuma le temps du redémarrage.
- Un fichier SQLite copié pendant une écriture peut être incohérent :
  la procédure de sauvegarde et de restauration est décrite et testée
  dans `services/forgejo/BACKUP.md`.
- Le retour à une version antérieure de Forgejo n'est pas possible
  après une migration de base : sauvegarder avant chaque montée de
  version.
- Une montée de version majeure est à prévoir avant le 2027-07-15
  (prochaine LTS : 19.0, annoncée pour le 2027-04-15). Le saut direct
  de 15 vers 19 est à vérifier dans les notes de version.
- Les clients doivent ajouter `git.bb-homelab.local` à leur fichier
  `hosts` et faire confiance à la CA interne de Caddy, comme pour les
  autres sites.

**Risque résiduel** : les conteneurs en `network_mode: host` joignent
l'IP du conteneur Forgejo sans passer par Caddy, comme pour les autres
backends (suivi dans #216).

## Alternatives considered

- **Gitea** : même base de code d'origine ; Forgejo est gouverné par
  une association et publie une ligne LTS.
- **GitLab CE** : trop lourd pour un Pi partagé (plusieurs Go de RAM).
- **Dépôts nus servis par le sshd de l'hôte** : pas d'interface web, ni
  tickets, ni revues.
- **Rester sur GitHub seul** : ne répond pas au besoin de contrôle.

## Refs

- Issue #260
- [ADR 0002](0002-caddy-reverse-proxy.md) — Caddy et sa CA interne
- [ADR 0007](0007-docker-published-ports-binding.md) — liaison des ports
- [ADR 0009](0009-per-backend-proxy-networks.md) — un réseau proxy par
  backend
- Diagramme
  [`08-deployment.md`](../architecture/diagrams/forgejo/08-deployment.md)
