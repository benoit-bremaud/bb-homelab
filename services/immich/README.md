# Immich — source des captures d'écran du téléphone

Immich reçoit l'album Captures d'écran du téléphone Android et sert de
source, d'archive privée et de recherche au pipeline screenshot-triage
(issue #224, [ADR 0010](../../docs/decisions/0010-immich-screenshot-source.md),
[diagrammes](../../docs/architecture/diagrams/immich/01-deployment.md)).

## Ce qui tourne

| Conteneur | Rôle | Port publié |
|---|---|---|
| `bb-homelab-immich-server` | API, site web, tâches | `2283` sur `127.0.0.1` et l'IP tailnet seulement |
| `bb-homelab-immich-machine-learning` | OCR seul, la nuit | aucun |
| `bb-homelab-immich-postgres` | Base de données | aucun |
| `bb-homelab-immich-redis` | File des tâches (Valkey) | aucun |

Accès :

- **Téléphone** : `http://bb-homelab:2283`, dans le tunnel Tailscale, à la
  maison et en Wi-Fi seulement. L'app Immich n'accepte pas la CA interne
  de Caddy.
- **PC et screenshot-triage** : `https://immich.bb-homelab.local` via
  Caddy. Ajouter à `/etc/hosts` du PC :

  ```text
  100.121.134.61  immich.bb-homelab.local
  ```

Données : `/mnt/appdata/immich/{library,postgres,model-cache,db-dumps}`
(Disque A). Sauvegarde et restauration : [BACKUP.md](BACKUP.md).

## Déploiement (première fois)

Vérifier d'abord la place et la mémoire, puis que la liaison sortante du
Pi télécharge correctement (#237) :

```bash
df -h / /mnt/appdata
free -h
```

```bash
sudo mkdir -p /mnt/appdata/immich/{library,postgres,model-cache,db-dumps}
sudo chown benoit:benoit /mnt/appdata/immich/db-dumps
docker network inspect bb-homelab-proxy-immich >/dev/null 2>&1 \
  || docker network create bb-homelab-proxy-immich
cd ~/bb-homelab/services/immich
cp .env.example .env    # DB_PASSWORD aléatoire, rangé dans le gestionnaire de mots de passe
chmod 600 .env
docker compose up -d
docker compose ps       # les quatre conteneurs « healthy »
```

Puis recréer Caddy (`services/caddy`, `docker compose up -d`) pour qu'il
rejoigne le réseau, et vérifier qu'aucun port ne s'est ouvert sur le Wi-Fi :

```bash
sudo ss -tlnpH | grep 2283    # seulement 127.0.0.1 et 100.121.134.61
```

## Configuration (étapes du propriétaire)

Faire ces étapes **juste après** le premier démarrage : l'inscription
administrateur reste ouverte tant qu'aucun compte n'existe.

1. **Compte administrateur** : ouvrir `https://immich.bb-homelab.local`,
   créer le compte, ranger le mot de passe dans le gestionnaire de mots
   de passe.
2. **Réglages serveur** (Administration → Paramètres) :
   - Apprentissage automatique : désactiver la recherche intelligente et
     la reconnaissance faciale, garder l'OCR.
   - Tâches : concurrence 1 pour l'OCR et les vignettes ; OCR planifié la
     nuit.
   - Corbeille : activée, rétention 30 jours au moins.
   - Désactiver la vérification de nouvelle version et les tuiles de carte
     externes.
3. **App Android** :
   - serveur `http://bb-homelab:2283`, Tailscale actif ;
   - sauvegarde : **album Captures d'écran seul**, jamais toute la
     pellicule ;
   - envoi en Wi-Fi seulement ;
   - mise à jour automatique de l'app désactivée dans le Play Store.
   - Contrôle : le site web ne montre que des captures d'écran.
4. **Clé d'API de screenshot-triage** (Paramètres du compte → Clés d'API) :
   - nom daté, par exemple `screenshot-triage-pc-2026-11` ;
   - permissions limitées à ce que le pipeline appelle : `asset.read`,
     `asset.view`, `asset.download`, `asset.update`, `asset.delete`,
     `album.read`, `albumAsset.create`, `albumAsset.delete`, `tag.read`,
     `tag.create`, `tag.asset` ; vérifier la liste contre la séquence de
     screenshot-triage #3 ;
   - Immich ne donne pas de date d'expiration aux clés : ranger la clé
     dans le gestionnaire de mots de passe avec un rappel de rotation à
     6 mois.
   - `asset.delete` permet une purge définitive (`force`) : la corbeille
     et la copie du portable sont le filet de sécurité.
5. **Uptime Kuma** : moniteur HTTP sur
   `https://immich.bb-homelab.local/api/server/ping`, au moins deux
   essais ; sonde Push `backup-immich` ([BACKUP.md](BACKUP.md)).

Avant de vider la pellicule, suivre la règle du
[diagramme d'activité](../../docs/architecture/diagrams/immich/03-activity.md) :
test de restauration réussi, copie du portable vérifiée, captures de plus
de 2 jours seulement.

## Mise à jour et retour arrière

1. Lire les notes de version d'Immich : les versions majeures cassent
   souvent la compatibilité.
2. Lancer `db-dump.sh` à la main.
3. Changer les images (version **et** empreinte) dans
   `docker-compose.yml`, d'après le compose officiel de la nouvelle
   version, puis `docker compose pull && docker compose up -d`.
4. Mettre à jour l'app Android **après** le serveur.

Retour arrière : remettre l'ancienne version dans le compose. Si la base a
été migrée, restaurer le dump de l'étape 2 ([BACKUP.md](BACKUP.md)).

## Opérations

- Logs : `docker compose logs -f immich-server`.
- Santé : `curl -fsS http://127.0.0.1:2283/api/server/ping`.
- Si l'OCR charge trop le Pi, il peut être déporté sur le portable de la
  maison (ADR 0010, point 1).
