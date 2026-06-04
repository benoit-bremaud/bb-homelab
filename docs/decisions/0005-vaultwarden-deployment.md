# ADR 0005 — Vaultwarden comme coffre de mots de passe self-hosted

- **Status**: Accepted
- **Date**: 2026-06-03

## Context

Le homelab et ses projets consommateurs ont besoin d'un coffre de mots de
passe privé, self-hosted — un endroit pour ranger des identifiants
humains (logins, codes de récupération, notes sécurisées) accessible
depuis les navigateurs et les téléphones, sans dépendre d'un cloud tiers.
L'issue #25 le suivait comme « nice-to-have » ; les pré-requis qu'elle
attendait sont désormais en place : reverse proxy Caddy avec la CA interne
(ADR 0002), le HDD `/mnt/appdata` (storage `LAYOUT.md`), l'accès
Tailscale-only (décision #28) et le monitoring Uptime Kuma (ADR 0004).

Deux produits portent le mot « vault » et ne doivent pas être confondus :

- **Vaultwarden** — un serveur Rust léger implémentant l'API Bitwarden.
  Secrets statiques (mots de passe, notes, pièces jointes) pour des
  utilisateurs humains, consommés via les extensions/apps Bitwarden.
  SQLite, quelques dizaines de Mo de RAM.
- **HashiCorp Vault** — un moteur de gestion de secrets d'entreprise pour
  l'infra/les apps (secrets dynamiques, leasing, politiques, audit).
  Lourd à opérer, destiné à des consommateurs machine.

Une contrainte réelle façonne le déploiement : le homelab n'a **pas encore
de backup unifié, hors-site et testé en restauration** (`/mnt/backup` non
monté — issue #19 ; seul n8n a des backups sur SD). Un coffre de mots de
passe dont tous les projets dépendent est la pire chose à transformer en
point de défaillance unique sans restauration prouvée.

## Decision

Déployer **Vaultwarden** sous `services/vaultwarden/`, en suivant le
pattern de service établi (n8n / caddy / kuma), avec ces sous-décisions :

1. **Vaultwarden plutôt que HashiCorp Vault.** Le besoin est la gestion
   de mots de passe pour utilisateurs humains, pas des secrets d'infra
   dynamiques. Vaultwarden répond au besoin à une fraction du coût
   opérationnel et tourne confortablement sur le Pi 5. C'est aussi
   cohérent avec la boîte à outils de conventions séparée `bb-vault`, qui
   standardise sur le CLI Bitwarden `bw`.

2. **Tailnet uniquement, aucun ingress public.** Joignable seulement via
   Caddy sur le réseau Tailscale (`vaultwarden.bb-homelab.local`, CA
   interne, aucun port hôte publié). Le coffre de mots de passe est le
   dernier service qui devrait être exposé sur internet ; cela s'aligne
   sur la décision #28 (aucun domaine possédé) et réutilise l'ADR 0002
   sans changement.

3. **Panel admin derrière un hash Argon2.** `ADMIN_TOKEN` est stocké comme
   hash Argon2 PHC dans `.env`, jamais en clair, donc le fichier au repos
   ne contient aucun credential utilisable. Le clair ne vit que dans un
   gestionnaire de mots de passe (break-glass).

4. **Instance fermée.** `SIGNUPS_ALLOWED=false` et
   `INVITATIONS_ALLOWED=false` après une fenêtre d'amorçage ponctuelle qui
   crée le compte unique ; la whitelist de domaines reste vide (une valeur
   non vide outrepasserait `SIGNUPS_ALLOWED=false`). Le push mobile est
   désactivé par défaut (il routerait les tokens device via le relais
   tiers de Bitwarden).

5. **Installer maintenant, mais PAS Tier-0 tant que backup + monitoring ne
   sont pas prouvés (la décision de gating).** Le service est installé et
   utilisable immédiatement, mais n'est *pas* traité comme une dépendance
   Tier-0 tant que quatre critères ne sont pas verts : (1) backup unifié
   hors-site via `restic` avec le Disque C monté (#19/#47), (2) un restore
   drill end-to-end documenté, (3) la sonde Uptime Kuma `/alive` verte sur
   le canal fault-only, (4) le dead-man's-switch Healthchecks.io vert.
   D'ici là, une copie break-glass (export chiffré du coffre + clair de
   l'admin-token + `rsa_key`/`config.json`) est gardée hors du Pi, et le
   gestionnaire de mots de passe existant reste la source de vérité pour
   les secrets les plus critiques. Raison : faire de Vaultwarden un Tier-0
   aujourd'hui créerait un point de défaillance unique sans restauration
   prouvée.

## Consequences

**Positives :**

- Un coffre privé, self-hosted, accessible depuis les navigateurs et les
  téléphones, avec rien dans un cloud tiers.
- Réutilise les couches proxy/CA/storage/monitoring existantes — ajouter
  le service se résume à un dossier + une route Caddyfile.
- La posture « installer maintenant, gater le Tier-0 » capte la valeur
  immédiatement tout en refusant le risque de point de défaillance unique
  tant que la restauration n'est pas prouvée.
- Compatible avec `bb-vault` : cette boîte à outils pourra plus tard
  pointer `bw config server` vers cette instance sans changement ici.

**Négatives :**

- Un nouveau service à état, sensible côté sécurité, à opérer, sauvegarder
  et garder patché (image épinglée ; bump délibéré).
- La discipline break-glass (garder un export chiffré + le clair de
  l'admin hors-Pi) est une habitude manuelle jusqu'à la fermeture du gate
  Tier-0.
- **Pas encore de SMTP** : pas de 2FA / indice par email, et les
  utilisateurs invités doivent être confirmés manuellement depuis
  `/admin`. Acceptable pour une instance mono-utilisateur (plus tard
  petite famille) ; à revoir quand un relais mail existera.
- Les données « crown jewels » (`db.sqlite3` + `rsa_key`) vivent sur un
  seul HDD avec uniquement des backups SD jusqu'à l'arrivée de #19 — la
  faille précise que le gate Tier-0 existe pour combler.

## Alternatives considered

- **HashiCorp Vault.** Rejeté : mauvais outil pour la gestion de mots de
  passe humains — moteur de secrets dynamiques destiné à des consommateurs
  infra/app, lourd à faire tourner sur un Pi, et qui jetterait le workflow
  `bw` aligné sur Bitwarden utilisé dans les projets.
- **Bitwarden cloud uniquement (pas de self-hosting).** Viable et
  zéro-ops, mais l'objectif explicite est de self-host le coffre dans le
  homelab. Conservé comme fallback break-glass pendant le gate Tier-0.
- **Faire de Vaultwarden un Tier-0 immédiatement.** Rejeté : sans backup
  unifié, hors-site et testé, une panne disque signifierait la perte
  définitive de tout secret stocké. Le gate diffère ce statut jusqu'à ce
  que la restauration soit prouvée.
- **L'exposer publiquement via un tunnel cloudflared nommé.** Rejeté :
  entre en conflit avec la décision #28 et met le service le plus
  sensible sur l'internet public.

## Refs

- Issue #25 — déploiement de Vaultwarden.
- Issue #19 — backups hors-site (restic) de `BACKUP_DIR` ; Disque C.
- ADR 0001 — découpage en couches DIP (ceci tient des couches 4-6 :
  packaging de service).
- ADR 0002 — reverse proxy interne Caddy (routage tailnet + CA interne).
- ADR 0004 — monitoring (sonde Uptime Kuma, switch Healthchecks.io).
- `services/vaultwarden/` — implémentation (compose, README, BACKUP,
  script de backup).
- Décision #28 — achat de domaine (différé) ; garde l'accès tailnet-only.
- Le repo séparé `bb-vault` — conventions de gestion de secrets sur le CLI
  `bw` ; pointera plus tard `bw config server` vers cette instance.
