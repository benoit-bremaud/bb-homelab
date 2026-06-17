# ADR 0006 — Homepage comme tableau de bord d'accueil

- **Status**: Accepted
- **Date**: 2026-06-17

## Context

Le homelab fait tourner 5 services (n8n, Jellyfin, Uptime Kuma,
Vaultwarden, Caddy) mais n'a **aucune page d'accueil** : chaque service
s'atteint en tapant son URL `*.bb-homelab.local`, et la seule vue d'état
est Uptime Kuma, isolé. Le besoin : un **point d'entrée unique** qui
liste les services et montre leur santé d'un coup d'œil. Un agrégateur
ne devient rentable qu'à partir de plusieurs services — c'est désormais
le cas (issue #125).

Le choix de l'outil a plus d'une réponse défendable (Homepage, Glance,
Dashy, Homarr), il mérite donc un ADR. Deux contraintes du repo pèsent
lourd sur la décision :

- **Config-as-code en git** : toute la configuration doit être
  versionnée et diffable, dans l'esprit CLEAN/SOLID appliqué à l'infra
  (ADR 0001).
- **Source de vérité du monitoring = Uptime Kuma** (ADR 0004) :
  l'agrégateur doit savoir lire son statut nativement.

Le tout en accès tailnet-only, sans ingress public (décision #28).

## Decision

### 1. Homepage (gethomepage), sur matrice pondérée

Comparaison chiffrée, critères pondérés par les contraintes ci-dessus
(note 1-5 par critère, somme pondérée sur 100) :

| Critère (poids) | Homepage | Glance | Dashy | Homarr |
|---|---|---|---|---|
| Config-as-code / git (25) | 5 | 5 | 5 | 2 |
| Widgets de statut natifs (20) | 4 | 3 | 3 | 5 |
| Empreinte Pi 5 / arm64 (15) | 4 | 5 | 3 | 2 |
| Local-first / sans compte (15) | 5 | 5 | 5 | 5 |
| Maintenance / communauté (10) | 5 | 4 | 4 | 5 |
| Facilité d'exploitation (10) | 4 | 4 | 4 | 5 |
| Sécurité (5) | 4 | 3 | 4 | 3 |
| **Score pondéré /100** | **90** | 86 | 81 | 74 |

Homepage gagne parce qu'il combine les deux critères les plus lourds :
config **100 % YAML versionnable** *et* **widget Uptime Kuma natif**.
Homarr est disqualifié par sa configuration en base SQLite non
diffable (incompatible avec le config-as-code) ; Glance n'a pas de
widget Uptime Kuma natif — or Kuma est la source de vérité du
monitoring (ADR 0004).

### 2. Cible d'intégration : Niveau 2, livré en 2 PR

- **L1 (cette PR)** : lanceur de liens + le présent ADR.
- **L2 (PR suivante)** : widget de statut Uptime Kuma — il lit une
  *status page* publique par slug, sans clé API, sans login, sans
  socket Docker.
- **L3 (stats CPU/RAM live par conteneur) reporté** : sur 5 conteneurs
  l'apport est faible et cela exigerait d'exposer le socket Docker
  (équivalent root sur l'hôte). Hors périmètre, à reconsidérer dans un
  ADR dédié (« exposition du socket Docker »).

### 3. Config dans le repo, pas sur `/mnt/appdata`

La configuration vit dans `services/homepage/config/`, bind-montée en
relatif (`./config:/app/config`), comme `services/caddy/` monte
`./Caddyfile`. C'est une **dérogation délibérée et documentée au
Pattern Y** : Homepage n'a aucun état runtime en L1/L2, sa config est
du *code*, pas de l'*appdata* — le dashboard démarre même si le HDD est
démonté.

Les logs partent vers stdout (`LOG_TARGETS=stdout`) et les **9 fichiers
de config sont committés**, pour que Homepage n'écrive rien dans le
dossier suivi par git au démarrage : il ne crée que les fichiers
manquants, n'écrase jamais.

## Consequences

**Positives :**

- Config-as-code intégrale : tout `/app/config` est versionné, diffable
  et revu en PR.
- Une seule route Caddy (ADR 0002, couche 5 d'ADR 0001) — exactement le
  pattern des autres services.
- Aucune dépendance HDD : le dashboard démarre même si `/mnt/appdata`
  est démonté.
- Réutilise Uptime Kuma (ADR 0004) comme source de statut en L2 — pas
  de second système de monitoring.
- Aucun secret introduit (L1/L2 : le widget lit une status page
  publique par slug).

**Négatives / à revisiter :**

- Dérogation au Pattern Y (pas de `/mnt/appdata`) — justifiée par
  l'absence d'état runtime ; à revoir si Homepage acquiert un jour un
  état persistant.
- L3 (stats Docker live) reporté : nécessitera un ADR sur l'exposition
  du socket Docker (risque équivalent-root).
- 5 fichiers de config placeholder (`docker.yaml`, `kubernetes.yaml`,
  `proxmox.yaml`, `custom.css`, `custom.js`) committés pour empêcher la
  génération de squelettes — légère verbosité, mais documente
  l'intention de ne pas activer ces intégrations.

## Alternatives considered

- **Glance.** Léger, config YAML, mais **pas de widget Uptime Kuma
  natif** — or Kuma est la source de vérité du monitoring (ADR 0004).
  86/100. Rejeté.
- **Dashy.** Riche fonctionnellement, mais pas de widget Docker natif
  et build lourd. 81/100. Rejeté.
- **Homarr.** UI soignée, mais configuration en base SQLite **non
  diffable** (incompatible avec le config-as-code) et empreinte
  ~600 Mo. 74/100. Rejeté.

## Refs

- Issue #125 — infra(services): deploy Homepage dashboard (Level 1 link
  launcher) + ADR 0006
- ADR 0001 — DIP layering (Homepage occupe les couches 5/6 : packaging
  applicatif + service)
- ADR 0002 — Caddy reverse proxy (la route qui fronte Homepage)
- ADR 0004 — Architecture de monitoring (Uptime Kuma, source du widget
  de statut L2)
- Décision #28 — pas d'ingress public (tailnet-only)
- `services/homepage/` — implémentation
- `storage/LAYOUT.md` — Pattern Y (la dérogation y est assumée)
