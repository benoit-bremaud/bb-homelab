# ADR 0014 — Rôle de Forgejo face à GitHub

- **Status**: Accepted
- **Date**: 2026-11-26

## Context

L'ADR 0011 a déployé Forgejo sur le Pi (`git.bb-homelab.local`, tailnet
seul) sans trancher son rôle face à GitHub : miroir, forge principale
ou remplacement. L'epic #262 organise la migration ; cet ADR fixe son
cadre (issue #281).

Inventaire du 2026-11-26 :

- 137 dépôts sur le compte `benoit-bremaud` (environ 1,16 Go), plus de
  50 dans l'organisation `StudioB22`.
- 84 projets GitHub Projects v2 ; 31 clones locaux portent encore
  `.github/workflows/`.
- Environ 60 dépôts publics, conformément à la règle « public par
  défaut » de l'ADR-0005 des règles globales du propriétaire (dépôt
  agents-skills).

Les décisions ci-dessous ont été prises par le propriétaire le
2026-11-26 (section « Decisions » de #262). Les matrices MCDA (poids
/100, notes 0–5, total /500) sont résumées par leurs totaux.

## Decision

1. **Forgejo devient la forge principale** de tous les dépôts actifs
   de `benoit-bremaud` et de l'organisation `StudioB22`. Restent sur
   GitHub : les forks, les dépôts archivés et les exercices scolaires
   (`tp*`, `eval-*`, `kaggle-*`). `VEV-platform-services` (employeur)
   est hors périmètre. Accès par le tailnet seul.

2. **Tout est privé sur Forgejo, sans miroir push vers GitHub.**

   | Option | Total /500 |
   | --- | --- |
   | A. Privé sur Forgejo + miroir push public vers GitHub | 445 |
   | **B. Tout privé, aucun miroir** | **375** |
   | C. Rester sur GitHub | 350 |

   Le propriétaire a retenu B en connaissance de cause, malgré le
   meilleur score de A, et accepte la perte de visibilité du
   portfolio. Cette décision remplace,
   pour les dépôts migrés, la règle « public par défaut » (ADR-0005
   des règles globales) ; l'amendement de cette règle est suivi dans
   agents-skills (voir Refs).

3. **Ce qui change d'outil** :
   - Dependabot est remplacé par Renovate (#297).
   - GitHub Projects v2 est remplacé par les tableaux de projet natifs
     de Forgejo : un par dépôt, des tableaux d'organisation pour les
     projets transverses (#316).

     | Option | Total /500 |
     | --- | --- |
     | **A. Tableaux Forgejo** | **410** |
     | B. Plane auto-hébergé | 325 |
     | C. Linear | 280 |

     Linear est rejeté : service SaaS, sans intégration Forgejo.
   - GitHub Pages et les déploiements liés à GitHub sont inventoriés
     dans #313 avant toute migration du dépôt concerné.

4. **Contenu migré** : historique git complet, toutes les issues et
   pull requests (numéros conservés), labels, milestones ; releases
   pour les cinq dépôts qui en ont. Aucun dépôt n'utilise LFS ; les
   wikis seulement là où l'inventaire trouve du contenu.

5. **Les copies GitHub sont archivées, pas supprimées** (#321), une
   fois la migration de chaque dépôt vérifiée.

## Consequences

**Positive:**

- Une seule forge principale, sous contrôle du propriétaire, sans
  dépendance à un service tiers ni jeton GitHub sur le Pi.
- Le code, les issues et les tableaux vivent au même endroit.
- Aucune copie publique à garder cohérente.

**Negative:**

- Environ 60 dépôts publics quittent le profil public : le portfolio
  GitHub perd sa visibilité, les liens externes (CV, posts, README
  d'autres dépôts) cassent ou pointent vers des copies archivées.
- Le Pi devient le point unique de défaillance de toutes les forges :
  une instance, SQLite, une sauvegarde par nuit. La capacité disque
  (#312), la perte de données acceptée et le chemin de reprise sont à
  fixer avant la vague 1.
- `just gate` et `just merge` écrivent un statut de commit et
  fusionnent via l'API GitHub : leur portage vers l'API Forgejo
  (#311) bloque la migration de tout dépôt attesté.
- Les skills, hooks et serveurs MCP qui supposent GitHub doivent
  gagner un chemin Forgejo (benoit-bremaud/agents-skills#563).
- Les 31 clones portant `.github/workflows/` seraient exécutés par
  Forgejo Actions si un runner était branché : à nettoyer avant
  migration (#314).
- Ce dépôt est public depuis le 2026-06-16 ; il passera privé à sa
  propre migration.

## Alternatives considered

- **A. Privé sur Forgejo + miroir push vers GitHub (445)** : garde le
  portfolio, mais exige un jeton d'écriture GitHub stocké sur la forge
  et maintient deux copies ; écarté par le propriétaire.
- **C. Rester sur GitHub (350)** : ne répond pas au besoin de contrôle
  qui a motivé l'ADR 0011.
- **Plane et Linear** pour les tableaux : voir le point 3.

## Refs

- Issues #281, #262 (epic), #297, #311, #312, #313, #314, #316, #321
- [ADR 0011](0011-forgejo-git-forge.md) — Forgejo comme forge git
  auto-hébergée
- benoit-bremaud/agents-skills#563 — chemin Forgejo pour l'outillage
  des agents
- Amendement de la règle de visibilité (ADR-0005 global) :
  benoit-bremaud/agents-skills#582
