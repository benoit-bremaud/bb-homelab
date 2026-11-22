# services/forgejo

Forgejo, la forge git auto-hébergée du homelab : dépôts, tickets et revues
sur le tailnet via `https://git.bb-homelab.local` (issue #260,
[ADR 0011](../../docs/decisions/0011-forgejo-git-forge.md)).

Schéma de déploiement :
[`08-deployment.md`](../../docs/architecture/diagrams/forgejo/08-deployment.md).

## Stack

- Image : `codeberg.org/forgejo/forgejo`, variante rootless de la ligne
  LTS 15, épinglée par `FORGEJO_IMAGE_TAG` (défaut dans le compose).
- Un seul conteneur, `bb-homelab-forgejo` : utilisateur `1000:1000`
  (`FORGEJO_UID` / `FORGEJO_GID`, le `benoit` du Pi),
  `cap_drop: [ALL]`, `no-new-privileges`, racine en lecture seule, `/tmp`
  en tmpfs, 512 Mo sans swap, 256 pids.
- Base SQLite, dans le dossier de données.
- Données (bind-mount HDD, Pattern Y, `create_host_path: false`) :

  | Hôte | Conteneur | Contenu |
  | --- | --- | --- |
  | `/mnt/appdata/forgejo` | `/var/lib/gitea` | dépôts git, base SQLite, `custom/conf/app.ini`, clé d'hôte SSH, pièces jointes |

- Réseau :
  - web : port `3000` non publié, joint par Caddy seul sur
    `bb-homelab-proxy-forgejo` (ADR 0009) ;
  - git en SSH : serveur SSH intégré, publié sur `100.121.134.61:2222`
    seulement (ADR 0007). Ne jamais le lier à `0.0.0.0` : Docker
    contourne UFW.
- Instance fermée : inscription désactivée, connexion obligatoire pour
  tout lire, assistant d'installation verrouillé, pas de runner Actions.
  Git LFS n'est pas activé.
- Réglages d'instance (#268), tous dans le compose :

  | Réglage | Valeur | Effet |
  | --- | --- | --- |
  | `APP_NAME` | `bb-homelab git` | titre de l'instance |
  | `[repository] FORCE_PRIVATE` | `true` | tout dépôt est créé privé, par le web comme par l'API ; un admin peut le publier après coup |
  | `[repository] DEFAULT_PRIVATE` | `private` | case « privé » cochée dans le formulaire web |
  | `[service] DEFAULT_ORG_VISIBILITY` | `private` | valeur présélectionnée dans le formulaire web |
  | `[service] DEFAULT_USER_VISIBILITY` | `private` | tout nouveau compte est privé par défaut (web, CLI, API sans `visibility` explicite) ; le compte `benoit`, créé avant, garde sa visibilité |
  | `[security] GLOBAL_TWO_FACTOR_REQUIREMENT` | `all` | double authentification obligatoire pour tous les comptes |
  | `[session] PROVIDER` | `db` | sessions en base : un redémarrage ne déconnecte plus |
  | `[mailer] ENABLED` | `false` | aucun courriel : ni notification, ni réinitialisation de mot de passe (passer par la CLI) |

  `DEFAULT_PRIVATE` et `DEFAULT_ORG_VISIBILITY` ne valent que pour le
  formulaire web : l'API les ignore (vérifié sur 15.0.12). Rien ne
  force la visibilité d'une organisation : la créer
  avec `visibility: private` explicite et le vérifier ensuite.
  Avec la double authentification obligatoire, le jeton d'API d'un
  compte sans second facteur est refusé.

## Bootstrap

Sur le Pi (`ssh benoit@bb-homelab`), le disque appdata monté :

```bash
mountpoint -q /mnt/appdata || { echo "ERREUR : /mnt/appdata non monté"; exit 1; }

# 1. Dossier de données, au propriétaire du conteneur (FORGEJO_UID:GID),
#    et dossier des archives, attendu par la copie nocturne vers le PC.
sudo install -d -o 1000 -g 1000 -m 700 /mnt/appdata/forgejo
install -d -m 700 ~/backups/forgejo

# 2. Réseau partagé avec Caddy (une fois)
docker network inspect bb-homelab-proxy-forgejo >/dev/null 2>&1 \
  || docker network create bb-homelab-proxy-forgejo

# 3. Configuration. La clé secrète est écrite dans .env sans jamais
#    s'afficher. Un .env existant n'est pas touché : le réécrire
#    changerait la clé. La dernière ligne doit répondre 1.
cd ~/bb-homelab/services/forgejo
if [ -e .env ]; then
  echo ".env existe déjà : étape 3 ignorée"
else
  (umask 077; cp .env.example .env)
  sed -i '/^FORGEJO_SECRET_KEY=/d' .env
  printf 'FORGEJO_SECRET_KEY=%s\n' "$(openssl rand -hex 32)" >> .env
fi
grep -c '^FORGEJO_SECRET_KEY=[A-Za-z0-9_-]\{32,\}$' .env

# 4. Démarrage
docker compose up -d
docker compose ps        # attendu : healthy
```

Copier la valeur de `FORGEJO_SECRET_KEY` dans le gestionnaire de mots de
passe. Le compose l'impose depuis `.env` à chaque démarrage : avec une
autre clé, Forgejo ne peut plus lire les secrets 2FA ni les jetons
enregistrés, même si l'archive de sauvegarde contient l'ancienne dans
`app.ini`.

Puis recréer Caddy (`services/caddy`, `docker compose up -d`) : il rejoint
le réseau et sert le site. Toutes les sondes Kuma tombent le temps du
redémarrage.

### Compte administrateur

Le propriétaire le crée lui-même, dans son terminal :

```bash
docker exec -it bb-homelab-forgejo forgejo admin user create \
  --admin --username <nom> --email <adresse> --random-password \
  --must-change-password=true
```

Le mot de passe s'affiche une seule fois. Forgejo demande de le changer à
la première connexion (option explicite : le premier compte en est
dispensé par défaut) : enregistrer le nouveau dans le gestionnaire de mots
de passe. La double authentification est obligatoire : Forgejo l'impose
à la première connexion (Paramètres → Sécurité) et refuse le jeton d'API
d'un compte qui ne l'a pas. Garder le code de secours dans le
gestionnaire de mots de passe. Second facteur perdu : depuis le Pi,

```bash
docker exec -it bb-homelab-forgejo forgejo admin user reset-mfa --username <nom>
```

puis réenrôler un second facteur à la connexion suivante.

### Clients

Sur chaque client, ajouter à `/etc/hosts` :

```text
100.121.134.61  git.bb-homelab.local
```

La CA interne de Caddy doit être de confiance, comme pour les autres sites
([README Caddy](../caddy/README.md)).

### Supervision

- Uptime Kuma : moniteur HTTP sur
  `https://git.bb-homelab.local/api/healthz`, au moins deux essais.
- Sauvegarde : moniteur Push `backup-forgejo`, voir [Sauvegarde](#sauvegarde).

### Essais du premier déploiement

Résultats dans `PROJECT_LOG.md` :

- fait le 2026-11-21 : restauration d'une archive avec un dépôt d'essai
  ([APPDATA-BACKUP.md](../../storage/APPDATA-BACKUP.md#restauration)) ;
- fait le 2026-11-21 : empreinte de la clé d'hôte SSH relevée (ci-dessous) ;
- reste à faire : envoi par le web d'un fichier de plus de 64 Mo et
  fusion d'une PR. Le `/tmp` du conteneur est un tmpfs de 64 Mo
  (`GITEA_TEMP`) : en cas d'échec, agrandir le tmpfs ou déplacer le
  dossier temporaire sous `/var/lib/gitea`.

## Utiliser git

Ajouter sa clé publique dans Forgejo (Paramètres → Clés SSH / GPG), puis
dans `~/.ssh/config` du client :

```text
Host git.bb-homelab.local
  User git
  Port 2222
  IdentityFile ~/.ssh/id_ed25519_forgejo
  IdentitiesOnly yes
```

`IdentityFile` désigne la clé dédiée à Forgejo ; `IdentitiesOnly` empêche
`ssh` de proposer les autres clés du client.

```bash
git clone git@git.bb-homelab.local:<utilisateur>/<dépôt>.git
```

Sans cette entrée, l'URL complète est
`ssh://git@git.bb-homelab.local:2222/<utilisateur>/<dépôt>.git`.

À la première connexion, comparer l'empreinte proposée par `ssh` avec
celle relevée **depuis le Pi lui-même** (session SSH d'administration) :
lancée depuis le client, la commande ne prouverait rien.

```bash
ssh-keyscan -p 2222 100.121.134.61 2>/dev/null | ssh-keygen -lf -
```

Empreinte relevée le 2026-11-21 :
`SHA256:0VjmYCYyYZkIa36N4JAtcgL6BqSsMC/4KQBs6/o73jQ`.

Le port 2222 est aussi filtré par la politique d'accès du tailnet : seul
le PC de développement (`100.67.85.126`) y est autorisé. Un nouveau
client doit y être ajouté par le propriétaire, dans la console Tailscale.

Le clone en HTTPS (`https://git.bb-homelab.local/<utilisateur>/<dépôt>.git`)
demande un jeton d'accès Forgejo et que git fasse confiance à la CA interne.

## API et jeton des agents

- Base : `https://git.bb-homelab.local/api/v1`, en-tête
  `Authorization: token <valeur>`.
- Jeton `user-benoit-agents-2026` du compte `benoit` : écriture sur
  `repository`, `issue` et `organization`, lecture sur `user` ; ni
  `admin` ni `notification`. Créer un dépôt sous un compte
  (`POST /user/repos`) demande `write:user` : ce jeton ne crée des
  dépôts que sous une organisation.
- Pas d'expiration : l'API de Forgejo 15 n'en propose pas (champs
  `name`, `scopes`, `repositories` seulement). Rotation à la main, en
  créant le nouveau jeton avant de révoquer l'ancien ; rappel en 2027-11.
- Risque résiduel : le jeton appartient à un compte admin. Avec la seule
  portée `write:repository`, il peut repasser un dépôt en public
  (`PATCH`, vérifié sur 15.0.12) : `FORCE_PRIVATE` ne bloque que les
  non-admins. Effet limité tant que l'instance exige une connexion pour
  tout lire et n'a qu'un compte.
- Valeur : fichier `~/.config/forgejo/token` du PC de développement
  (`600`, dossier en `700`). Elle ne va ni dans git, ni dans une
  commande affichée, ni dans une discussion :

  ```bash
  curl -fsS -H @<(printf 'Authorization: token %s' "$(cat ~/.config/forgejo/token)") \
    https://git.bb-homelab.local/api/v1/user
  ```

## Variables d'environnement

`.env` (hors git, `chmod 600`) :

| Variable | Défaut | Rôle |
| --- | --- | --- |
| `FORGEJO_SECRET_KEY` | aucun, **obligatoire** | clé secrète globale ; le compose refuse de démarrer sans elle |
| `FORGEJO_IMAGE_TAG` | celui du compose | version de l'image |
| `FORGEJO_UID` / `FORGEJO_GID` | `1000` | utilisateur du conteneur et propriétaire des données |
| `FORGEJO_LOG_LEVEL` | `Info` | niveau de journalisation |
| `TZ` | `Europe/Paris` | fuseau horaire |

Les autres réglages sont dans le compose (`FORGEJO__<section>__<CLÉ>`) :
Forgejo les réécrit dans `app.ini` à chaque démarrage. Un réglage modifié
à la main dans `app.ini` et présent dans le compose est donc écrasé.

## Sauvegarde

Tout `/var/lib/gitea` est archivé chaque nuit à 03:35 par le script
commun, puis copié sur le PC. Installation, vérification d'une archive et
restauration : [storage/APPDATA-BACKUP.md](../../storage/APPDATA-BACKUP.md).

## Mise à jour

1. Lire les notes de version (changements cassants).
2. Lancer la sauvegarde à la main (ligne cron de
   [APPDATA-BACKUP.md](../../storage/APPDATA-BACKUP.md)) et vérifier
   l'archive.
3. Changer `FORGEJO_IMAGE_TAG` dans `.env`, puis `docker compose up -d` :
   les migrations de base tournent au démarrage.

Retour arrière : une base migrée ne redescend pas. Arrêter Forgejo,
restaurer l'archive de l'étape 2
([procédure](../../storage/APPDATA-BACKUP.md#restauration)), remettre
l'ancien tag.

La ligne LTS 15 s'arrête le 2027-07-15 : passer à la LTS suivante (19.0,
annoncée pour le 2027-04-15) avant cette date.

## Notes de sécurité

- `FORGEJO_SECRET_KEY` vide ferait retomber Forgejo sur une clé publique
  dans son code source : le compose l'exige (`:?`).
- `app.ini` contient les jetons générés par Forgejo (`INTERNAL_TOKEN`,
  secret JWT) : il vit sur le HDD, dans un dossier en `700`, et dans les
  archives de sauvegarde (`chmod 600`).
- Le port 2222 n'accepte que l'authentification par clé publique, gérée
  dans Forgejo. Aucun compte système n'est créé sur le Pi.
- Risque résiduel : un conteneur en `network_mode: host` joint Forgejo
  sans passer par Caddy, comme les autres backends (#216).

## Refs

- Issues #260, #268
- [ADR 0011](../../docs/decisions/0011-forgejo-git-forge.md),
  [ADR 0007](../../docs/decisions/0007-docker-published-ports-binding.md),
  [ADR 0009](../../docs/decisions/0009-per-backend-proxy-networks.md)
- Documentation Forgejo : <https://forgejo.org/docs/v15.0/admin/>
