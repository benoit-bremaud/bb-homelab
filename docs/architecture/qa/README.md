# QA sur l'artefact réel — preuves

Étape 5 de la porte pré-merge (voir [AGENTS.md](../../../AGENTS.md) §4
et le skill `pr-workflow`). Ce dépôt n'a pas d'interface à lancer en
local : la QA se fait sur l'artefact réel, c'est-à-dire la configuration
validée en local puis, quand le diff touche un service, le service sur le
Pi.

## Procédure

1. **Diff docs ou règles uniquement** : lancer les linters
   (`markdownlint-cli2`, `yamllint`, `shellcheck`) et vérifier que les
   liens relatifs modifiés résolvent.
2. **Diff touchant un service** :
   - `docker compose -f services/<nom>/docker-compose.yml config` ;
   - pour Caddy : `caddy validate` sur le `Caddyfile` ;
   - après déploiement sur le Pi (demander confirmation avant toute
     opération sur l'état partagé) : `docker compose ps` (état
     `healthy`), puis `curl -sS -o /dev/null -w '%{http_code}'` sur la
     route concernée et sur les routes voisines (aucune régression).
3. **Captures** : pour tout service avec une interface (Homepage,
   Uptime Kuma, Jellyfin, Vaultwarden), une capture de la page
   concernée, sans donnée sensible (masquer jetons, identifiants,
   adresses privées).

## Conservation

Les preuves se rangent ici, sous
`docs/architecture/qa/<AAAA-MM-JJ>-<sujet>/` : un court `report.md`
(commandes lancées, codes de retour, SHA testé) et les captures.
Ne jamais y mettre de secret ni de capture montrant une valeur
secrète.
