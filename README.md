# bb-homelab

Homelab self-hosted sur un Raspberry Pi 5 : automatisation (n8n), futur
media center (Jellyfin), projets perso (brasse-bouillon), et l'écosystème
qui les entoure (reverse proxy, sauvegardes, monitoring).

Le repo est **hardware-agnostic par design** : aujourd'hui sur un Pi,
demain sur un mini-PC ou un VPS sans réécrire un service.

## Connexion rapide au Pi

```bash
ssh benoit@bb-homelab
# fallback si MagicDNS coince : ssh benoit@100.121.134.61
```

Détails (clé SSH, MagicDNS, hardening) : [network/tailscale.md](network/tailscale.md).

## Navigation

Le repo suit une **architecture en 6 couches DIP** (voir
[ARCHITECTURE.md](ARCHITECTURE.md) et
[docs/decisions/0001-dip-layering.md](docs/decisions/0001-dip-layering.md)).
Chaque couche a son dossier dédié et son README détaillé.

| Sujet | Où aller |
|---|---|
| Architecture & décisions | [ARCHITECTURE.md](ARCHITECTURE.md), [docs/decisions/](docs/decisions/) |
| **Setup d'un Pi from scratch** | [bootstrap/README.md](bootstrap/README.md) (pas-à-pas dans [bootstrap/FIRSTBOOT.md](bootstrap/FIRSTBOOT.md)) |
| **Réseau & accès distant** (Tailscale, reverse proxy) | [network/README.md](network/README.md), [network/tailscale.md](network/tailscale.md) |
| **Services déployés** (un dossier par stack docker-compose) | [services/README.md](services/README.md) — n8n, Caddy, … |
| **Stockage** (montages HDD, SMART, sauvegardes) | [storage/README.md](storage/README.md) |
| Journal opérationnel | [PROJECT_LOG.md](PROJECT_LOG.md) |
| Conventions de contribution | [CONTRIBUTING.md](CONTRIBUTING.md) |
| Instructions IA tooling | [AGENTS.md](AGENTS.md), [CLAUDE.md](CLAUDE.md) |

## Démarrer à zéro sur un nouveau Pi

L'objectif final est qu'un Pi neuf (ou une carte SD vierge) soit prêt
à faire tourner les services en exécutant un seul script de bootstrap.
En attendant, suivre les étapes manuelles dans
[bootstrap/FIRSTBOOT.md](bootstrap/FIRSTBOOT.md).

## Ce qui tourne aujourd'hui

L'état détaillé est dans [PROJECT_LOG.md](PROJECT_LOG.md). Le backlog
complet est sur [GitHub Issues](../../issues) et le project board.

## Conventions linguistiques

- **Documentation humain-facing** (ce README, `bootstrap/`, `network/`,
  `services/`, `storage/`, `ARCHITECTURE.md`, ADRs) : **français**.
- **Code, commits, messages de PR, comments inline** : **anglais**,
  par convention pro et pour rester lisible par les outils CI/CD.
- **Docs pour outils IA tooling** (`AGENTS.md`, `CLAUDE.md`),
  **conventions PR/security** (`CONTRIBUTING.md`), et **journal
  opérationnel** (`PROJECT_LOG.md`) : **anglais**, pour cohérence
  avec les artefacts de code qu'ils référencent.

## Licence

Documentation et configuration : [CC BY-SA 4.0](LICENSE). Les snippets
de code (scripts shell, fichiers Compose) suivent la même licence sauf
mention contraire.
