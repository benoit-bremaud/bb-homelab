# services/vaultwarden — gestionnaire de mots de passe (compatible Bitwarden)

Vaultwarden est un serveur léger, self-hosted, qui parle l'API Bitwarden.
Il donne au homelab un coffre de mots de passe privé, accessible depuis
les extensions navigateur et les apps mobiles Bitwarden, sans rien
envoyer à un cloud tiers.

Accès **sur le tailnet uniquement** (aucun ingress public, décision #28),
derrière Caddy avec la CA interne (ADR 0002).

> **Statut — PAS encore une dépendance Tier-0 (issue #25).** Cette
> instance est installée et utilisable, mais le homelab n'a pas encore de
> backup unifié, hors-site et testé en restauration (`/mnt/backup` non
> monté — issue #19). Tant que les quatre critères de « graduation » de
> [BACKUP.md](BACKUP.md) ne sont pas verts, garde ton gestionnaire de
> mots de passe actuel comme source de vérité pour tes secrets les plus
> critiques, et appuie-toi sur la copie break-glass décrite là-bas. Voir
> l'ADR [0005](../../docs/decisions/0005-vaultwarden-deployment.md).

## Stack

- Image : `vaultwarden/server:1.36.0` (épinglée — bump délibéré via
  `.env`). Manifeste multi-arch : l'ARM64 est tiré automatiquement sur le
  Pi 5.
- **Aucun port hôte publié** : Caddy l'atteint comme `vaultwarden:80` via
  le réseau partagé `bb-homelab-proxy`. Surface d'attaque minimale pour
  la machine qui stocke tous les mots de passe.
- Données persistantes : bind-mount `/mnt/appdata/vaultwarden` (HDD,
  Pattern Y, rôle `appdata`) → `/data` dans le conteneur. Persiste tout
  l'état du coffre (`db.sqlite3`, `rsa_key.*`, `attachments/`, `sends/`,
  `config.json`). **Pré-requis** : le HDD doit être monté sur
  `/mnt/appdata` avant `docker compose up`. Le compose déclare
  `create_host_path: false`, donc si le disque n'est pas monté
  Vaultwarden refuse de démarrer (échec bruyant) au lieu de démarrer
  silencieusement sur une DB vide.
- Réseau : `bb-homelab-proxy` (partagé avec Caddy) + `default`.
- URL interne : `https://vaultwarden.bb-homelab.local` (via Caddy).

Voir [BACKUP.md](BACKUP.md) pour la procédure de sauvegarde &
restauration et le gate break-glass / Tier-0.

## Bootstrap

Pré-requis : Docker + Compose v2 (`bootstrap/bootstrap.sh`), le HDD monté
sur `/mnt/appdata`, le réseau proxy partagé présent, et la CA interne
Caddy installée sur ton client (voir
[services/caddy/README.md](../caddy/README.md)).

Sur le Pi (`ssh benoit@bb-homelab`) :

```bash
cd services/vaultwarden

# 1. Pré-vol : HDD monté + réseau proxy présent.
mountpoint -q /mnt/appdata || { echo "ERREUR : /mnt/appdata non monté"; exit 1; }
docker network inspect bb-homelab-proxy >/dev/null 2>&1 \
  || docker network create bb-homelab-proxy

# 2. Créer la cible du bind-mount sur le HDD (répertoire « crown jewels »).
#    Vaultwarden tourne en root dans l'image stock, donc pas de chown
#    nécessaire (contrairement à l'uid 1000 de n8n). Verrouiller le dir :
sudo mkdir -p /mnt/appdata/vaultwarden
sudo chmod 700 /mnt/appdata/vaultwarden

# 3. Générer le hash Argon2 PHC du token admin (demande le mot de passe
#    deux fois). SAUVEGARDER le mot de passe EN CLAIR dans le gestionnaire
#    de mots de passe MAINTENANT — c'est la clé break-glass de /admin et
#    elle ne vit nulle part ailleurs.
docker run --rm -it vaultwarden/server /vaultwarden hash

# 4. Créer .env, coller le hash dans VW_ADMIN_TOKEN ENTRE SIMPLES QUOTES,
#    en gardant des '$' simples. Les valeurs .env entre simples quotes sont
#    littérales → Compose n'interpole pas les segments '$...'. Ne PAS
#    doubler les '$' (ça, c'est la règle des valeurs inline du compose.yml).
cp .env.example .env
${EDITOR:-nano} .env
chmod 600 .env

# 5. Démarrer la stack et la regarder devenir healthy.
docker compose up -d
docker compose ps
docker compose logs -f vaultwarden   # attendre "Rocket has launched" ; Ctrl-C
```

La route Caddy (`vaultwarden.bb-homelab.local`) est livrée dans
`services/caddy/Caddyfile` avec ce service. L'appliquer sans redémarrer
Caddy :

```bash
docker exec bb-homelab-caddy caddy reload --config /etc/caddy/Caddyfile
```

Sur chaque poste **client** (une fois, si pas déjà fait pour d'autres
services), router le hostname vers l'IP Tailscale du Pi (cf.
`services/caddy/README.md` pour la CA) :

```text
100.121.134.61  vaultwarden.bb-homelab.local
```

### Créer le compte unique (signup dance)

L'inscription est fermée par défaut. Ouvrir une fenêtre ponctuelle, créer
ton compte, puis refermer :

```bash
# a. Ouvrir les inscriptions, ré-appliquer l'env (sans perte de données).
#    Mettre VW_SIGNUPS_ALLOWED=true dans .env (optionnellement
#    VW_SIGNUPS_DOMAINS_WHITELIST = ton domaine email), puis :
docker compose up -d

# b. Enregistrer le compte unique dans le navigateur sur
#    https://vaultwarden.bb-homelab.local
#    (mot de passe maître fort → gestionnaire de mots de passe).

# c. Refermer les inscriptions : remettre VW_SIGNUPS_ALLOWED=false, puis :
docker compose up -d
#    Vérifier que la page d'inscription ne propose plus la création de compte.

# d. Confirmer que le panel admin marche avec le mot de passe EN CLAIR sur
#    https://vaultwarden.bb-homelab.local/admin
#    (s'il le refuse, le hash n'est probablement pas entre simples quotes
#    dans .env).
```

Enfin, enregistrer une sonde Uptime Kuma sur `http://vaultwarden:80/alive`
(moniteur HTTP « status / keyword » attendant un code 200 — **pas** un
moniteur « JSON query » : `/alive` renvoie une simple chaîne timestamp,
pas un objet JSON), et lancer le premier backup (voir [BACKUP.md](BACKUP.md)).

## Variables d'environnement

| Variable | Rôle |
|---|---|
| `VW_ADMIN_TOKEN` | **Hash Argon2 PHC** du mot de passe `/admin` (jamais en clair). Échec immédiat si vide. Mettre le hash entre simples quotes dans `.env` (`$` simples). Le clair ne vit que dans le gestionnaire de mots de passe. |
| `VW_IMAGE_TAG` | Override du tag d'image (défaut `1.36.0`). Bump délibéré, testé d'abord. |
| `VW_DOMAIN` | Origine publique (défaut `https://vaultwarden.bb-homelab.local`). Doit correspondre au hostname Caddy sinon WebAuthn/2FA et les liens cassent. |
| `VW_SIGNUPS_ALLOWED` | Inscription ouverte (défaut `false`). `true` seulement pour l'amorçage ponctuel du compte. |
| `VW_SIGNUPS_DOMAINS_WHITELIST` | Restreint l'auto-inscription à ces domaines email pendant la fenêtre d'amorçage. |
| `VW_PUSH_ENABLED` | Push mobile via le relais Bitwarden (défaut `false`). L'activer route les tokens device via un tiers. |
| `VW_PUSH_INSTALLATION_ID` / `_KEY` | Identifiants push depuis <https://bitwarden.com/host> (seulement si push activé). |
| `TZ` | Fuseau horaire (défaut `Europe/Paris`). Variable conteneur/libc standard, pas un réglage Vaultwarden. |
| `VW_LOG_LEVEL` | Verbosité des logs (défaut `warn` ; valeurs : `trace`/`debug`/`info`/`warn`/`error`/`off`). |

Toutes les valeurs sensibles vivent dans `.env` (gitignoré). Ne jamais
committer `.env`.

## Notes de sécurité

- **Tailnet uniquement.** Aucun port hôte ; joignable seulement via Caddy
  sur le réseau Tailscale. Le coffre de mots de passe est le dernier
  service qui devrait être exposé sur internet.
- **Instance fermée.** `SIGNUPS_ALLOWED=false` et
  `INVITATIONS_ALLOWED=false` après l'amorçage — pas d'auto-inscription,
  pas de surface d'invitation.
- **Le token admin au repos est un hash.** Le `.env` contient le hash
  Argon2 PHC, pas un credential utilisable ; le clair ne vit que dans le
  gestionnaire de mots de passe.
- **Pas de SMTP (limitation connue).** Pas de serveur mail dans le
  homelab pour l'instant, donc pas de 2FA / indice par email, et tout
  utilisateur invité doit être confirmé manuellement depuis `/admin`.
  Acceptable pour une instance mono-utilisateur (plus tard petite famille).
- **Push désactivé par défaut** pour éviter de router les tokens push
  device via le relais tiers Bitwarden.

## Refs

- Issue #25 — déploiement de Vaultwarden.
- ADR [0005](../../docs/decisions/0005-vaultwarden-deployment.md) —
  décision de déploiement (pourquoi Vaultwarden plutôt que HashiCorp
  Vault, tailnet-only, CA interne, gating backup-avant-Tier-0).
- [BACKUP.md](BACKUP.md) — sauvegarde, restauration, break-glass, gate de
  graduation.
- Issue #19 — backups hors-site (restic) de `BACKUP_DIR`.
- Le repo séparé `bb-vault` standardise les conventions de gestion de
  secrets sur le CLI `bw` et pointera plus tard `bw config server` vers
  cette instance — suivi là-bas, pas ici.
