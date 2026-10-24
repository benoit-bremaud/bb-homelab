# QA — Vaultwarden 1.37.4 (PR #148, issue #146)

SHA testé : `da631403e237603594b6bd6c5ad2501a0d8d358e`. Date : 2026-10-24.

Le Pi tourne déjà en 1.37.4 via `VW_IMAGE_TAG=1.37.4` dans son `.env`
(déploiement fait le 2026-10-24 après une sauvegarde manuelle par
`scripts/backup.sh`). Cette PR aligne la valeur par défaut du dépôt.

## Contrôles locaux

| Contrôle | Résultat |
|---|---|
| `docker compose -f services/vaultwarden/docker-compose.yml config -q` | OK |
| `markdownlint-cli2` sur le README du service | 0 erreur |
| `yamllint` sur le compose | 1 avertissement de longueur de ligne, déjà présent sur `main` |
| `gitleaks detect` sur tout l'historique | aucune fuite |
| Fichiers `.env*` suivis hors `.env.example` | aucun |
| Porte SonarQube locale (projet `bb-homelab`) | `PASSED` |

## Contrôles sur le Pi

| Contrôle | Résultat |
|---|---|
| `docker compose ps` | `vaultwarden/server:1.37.4`, `healthy` |
| `GET /api/version` | `"1.37.4"` |
| `GET /alive` | 200 |
| `POST /identity/accounts/prelogin/password` | 200, la réponse contient `kdfSettings` |
| Route `vaultwarden` | 200 |
| Routes voisines `home`, `n8n`, `status` | 200, 200, 302 |
| Route `jellyfin` | non résolue depuis le poste de test (pas d'entrée DNS) ; conteneur `healthy` sur le Pi, sans lien avec ce diff |

Avant la mise à jour, la même requête de prelogin renvoyait seulement
`kdf`, `kdfIterations`, `kdfMemory` et `kdfParallelism`, sans `kdfSettings`.

## Capture

`01-web-vault-import-page.jpg` : coffre web servi par 1.37.4, page
d'import, aucun élément du coffre visible.
