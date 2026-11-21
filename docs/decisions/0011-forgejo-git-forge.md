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

   | Critère (poids) | A. SQLite | B. PostgreSQL (conteneur dédié) |
   | --- | --- | --- |
   | Simplicité d'exploitation (30) | 5 : un fichier | 3 : second conteneur, mot de passe |
   | Sauvegarde et restauration (25) | 5 : script commun | 3 : `pg_dump` à ajouter |
   | RAM sur le Pi (20) | 5 | 3 |
   | Concurrence (15) | 3 : suffit pour un utilisateur | 5 |
   | Évolutivité (10) | 3 | 5 |
   | **Total /500** | **450** | 350 |

   Sensibilité : B ne passe devant que si concurrence et évolutivité
   pèsent ensemble plus de 50.

2. **Git en HTTPS via Caddy et en SSH sur le tailnet.** Le site
   `git.bb-homelab.local` suit le patron des autres sites (`tls
   internal`, `tailnet_only`, `/api/healthz` ouvert pour Uptime Kuma).
   Le serveur SSH intégré de Forgejo est publié sur
   `100.121.134.61:2222` seulement.

   | Critère (poids) | A. HTTPS + SSH intégré, IP tailnet:2222 | B. HTTPS seul | C. SSH via le sshd de l'hôte |
   | --- | --- | --- | --- |
   | Confort quotidien (30) | 5 : clés SSH | 3 : jeton et CA interne par client | 5 |
   | Surface d'attaque (25) | 4 : un port, tailnet seul | 5 : aucun port en plus | 3 : touche le sshd du Pi |
   | Simplicité de configuration (20) | 4 | 5 | 1 : exclut l'image rootless |
   | Compatibilité outils (25) | 5 | 3 | 5 |
   | **Total /500** | **455** | 390 | 370 |

   Sensibilité : B ne gagne que si la surface d'attaque pèse plus de 55
   environ, les autres poids réduits en proportion.

   Écart avec l'ADR 0007 : le port 2222 est lié à l'IP tailnet seule,
   sans `127.0.0.1`. Aucune sonde locale ne passe par ce port (Kuma
   sonde `/api/healthz` via Caddy), la liaison loopback serait inutile.
   L'IP tailnet figure donc dans un compose de plus : la reprise décrite
   dans l'ADR 0007 s'y applique aussi.

   URL de clone :
   `ssh://git@git.bb-homelab.local:2222/<utilisateur>/<dépôt>.git`.

3. **Ligne LTS, version 15.0.12**, épinglée (fin de support
   2027-07-15).

   | Critère (poids) | A. LTS 15.0.12 | B. Stable 17.0.2 (fin de support 2027-01-28) |
   | --- | --- | --- |
   | Stabilité (35) | 5 | 4 |
   | Charge de montée de version (30) | 5 : une par an | 2 : une tous les trois mois, fenêtres de deux semaines |
   | Correctifs de sécurité (25) | 5 | 5 |
   | Nouvelles fonctions (10) | 2 | 5 |
   | **Total /500** | **470** | 375 |

   Sensibilité : B ne gagne que si les nouvelles fonctions pèsent plus
   de 32 environ, les autres poids réduits en proportion.

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
  la sauvegarde met le conteneur en pause pendant la copie. La
  procédure est décrite dans `storage/APPDATA-BACKUP.md` ; le test de
  restauration est à faire au premier déploiement.
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
