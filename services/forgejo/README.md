# services/forgejo

Forgejo, la forge git auto-hébergée du homelab : dépôts, tickets et revues
sur le tailnet via `https://git.bb-homelab.local` (issue #260,
[ADR 0011](../../docs/decisions/0011-forgejo-git-forge.md)).

Schéma de déploiement :
[`08-deployment.md`](../../docs/architecture/diagrams/forgejo/08-deployment.md).

## Stack

- Image : `codeberg.org/forgejo/forgejo:15.0.12-rootless` (ligne LTS, fin
  de support 2027-07-15), épinglée par `FORGEJO_IMAGE_TAG`.
- Un seul conteneur, `bb-homelab-forgejo` : utilisateur `1000:1000`,
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

## Bootstrap

Sur le Pi (`ssh benoit@bb-homelab`), le disque appdata monté :

```bash
mountpoint -q /mnt/appdata || { echo "ERREUR : /mnt/appdata non monté"; exit 1; }

# 1. Dossier de données et dossier de sauvegarde (attendu dès maintenant
#    par la copie nocturne vers le PC)
sudo install -d -o 1000 -g 1000 -m 700 /mnt/appdata/forgejo
install -d -m 700 ~/backups/forgejo

# 2. Réseau partagé avec Caddy (une fois)
docker network create bb-homelab-proxy-forgejo

# 3. Configuration. La clé secrète est écrite dans .env sans jamais
#    s'afficher ; la dernière ligne doit répondre 1.
cd ~/bb-homelab/services/forgejo
cp .env.example .env && chmod 600 .env
sed -i '/^FORGEJO_SECRET_KEY=/d' .env
printf 'FORGEJO_SECRET_KEY=%s\n' "$(docker run --rm --entrypoint /usr/local/bin/forgejo \
  codeberg.org/forgejo/forgejo:15.0.12-rootless generate secret SECRET_KEY)" >> .env
grep -c '^FORGEJO_SECRET_KEY=[A-Za-z0-9_-]\{32,\}$' .env

# 4. Démarrage
docker compose up -d
docker compose ps        # attendu : healthy
```

Copier la valeur de `FORGEJO_SECRET_KEY` dans le gestionnaire de mots de
passe : sans elle, une restauration ne peut plus lire les secrets 2FA.

Puis recréer Caddy (`services/caddy`, `docker compose up -d`) : il rejoint
le réseau et sert le site. Toutes les sondes Kuma tombent le temps du
redémarrage.

### Compte administrateur

Le propriétaire le crée lui-même, dans son terminal :

```bash
docker exec -it bb-homelab-forgejo forgejo admin user create \
  --admin --username <nom> --email <adresse> --random-password
```

Le mot de passe s'affiche une seule fois : l'enregistrer dans le
gestionnaire de mots de passe. Forgejo demande de le changer à la première
connexion. Activer ensuite la double authentification (Paramètres →
Sécurité).

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
- Sauvegarde : moniteur Push `backup-forgejo`, voir
  [BACKUP.md](BACKUP.md).

## Utiliser git

Ajouter sa clé publique dans Forgejo (Paramètres → Clés SSH / GPG), puis
dans `~/.ssh/config` du client :

```text
Host git.bb-homelab.local
  User git
  Port 2222
```

```bash
git clone git@git.bb-homelab.local:<utilisateur>/<dépôt>.git
```

Sans cette entrée, l'URL complète est
`ssh://git@git.bb-homelab.local:2222/<utilisateur>/<dépôt>.git`.

À la première connexion, comparer l'empreinte proposée par `ssh` avec
celle relevée sur le Pi :

```bash
ssh-keyscan -p 2222 100.121.134.61 2>/dev/null | ssh-keygen -lf -
```

Le clone en HTTPS (`https://git.bb-homelab.local/<utilisateur>/<dépôt>.git`)
demande un jeton d'accès Forgejo et que git fasse confiance à la CA interne.

## Variables d'environnement

`.env` (hors git, `chmod 600`) :

| Variable | Défaut | Rôle |
| --- | --- | --- |
| `FORGEJO_SECRET_KEY` | aucun, **obligatoire** | clé secrète globale ; le compose refuse de démarrer sans elle |
| `FORGEJO_IMAGE_TAG` | `15.0.12-rootless` | version de l'image |
| `FORGEJO_UID` / `FORGEJO_GID` | `1000` | utilisateur du conteneur et propriétaire des données |
| `FORGEJO_LOG_LEVEL` | `Info` | niveau de journalisation |
| `TZ` | `Europe/Paris` | fuseau horaire |

Les autres réglages sont dans le compose (`FORGEJO__<section>__<CLÉ>`) :
Forgejo les réécrit dans `app.ini` à chaque démarrage. Un réglage modifié
à la main dans `app.ini` et présent dans le compose est donc écrasé.

## Mise à jour

1. Lire les notes de version (changements cassants).
2. Lancer la sauvegarde à la main (ligne cron de [BACKUP.md](BACKUP.md))
   et vérifier l'archive.
3. Changer `FORGEJO_IMAGE_TAG` dans `.env`, puis `docker compose up -d` :
   les migrations de base tournent au démarrage.

Retour arrière : une base migrée ne redescend pas. Arrêter Forgejo,
restaurer l'archive de l'étape 2, remettre l'ancien tag.

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

- Issue #260
- [ADR 0011](../../docs/decisions/0011-forgejo-git-forge.md),
  [ADR 0007](../../docs/decisions/0007-docker-published-ports-binding.md),
  [ADR 0009](../../docs/decisions/0009-per-backend-proxy-networks.md)
- Documentation Forgejo : <https://forgejo.org/docs/v15.0/admin/>
