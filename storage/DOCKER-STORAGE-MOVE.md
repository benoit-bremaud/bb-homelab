# Déplacer le stockage Docker sur le HDD

Procédure pour sortir les images et les conteneurs de la carte SD et les
placer sur le disque des données `/mnt/appdata` (issue #202, étape 2,
décision : [ADR 0008](../docs/decisions/0008-docker-storage-on-appdata-disk.md)).
Une première copie se fait à chaud ; la coupure de tous les conteneurs,
Home Assistant compris, ne dure que la seconde copie, sans redémarrer le Pi.

## Pourquoi deux dossiers

Docker 29 utilise ici le
[stockage d'images de containerd](https://docs.docker.com/engine/storage/containerd/)
(`docker info` : `driver-type io.containerd.snapshotter.v1`). Les images et
leurs couches sont alors dans `/var/lib/containerd`, pas dans
`/var/lib/docker`, et changer `data-root` ne déplace pas le stockage de
containerd. Il faut donc déplacer les deux :

| Dossier sur la SD | Contenu | Réglage |
|---|---|---|
| `/var/lib/containerd` | images, couches, instantanés | `root` dans `/etc/containerd/config.toml` |
| `/var/lib/docker` | conteneurs, volumes nommés, réseaux | `data-root` dans `/etc/docker/daemon.json` |

L'état d'exécution (`/run/containerd`, `/run/docker`) est en mémoire et ne
bouge pas. Ne pas ajouter de ligne `version = …` à `config.toml` : la ligne
`disabled_plugins = ["cri"]` actuelle suppose le format sans version.

Docker attend déjà le HDD au démarrage (drop-in
`/etc/systemd/system/docker.service.d/appdata-mount.conf`,
`RequiresMountsFor=/mnt/appdata`). containerd reçoit le même drop-in.

## Conséquence à accepter

Sans le HDD, plus aucun conteneur ne démarre, y compris ceux qui n'ont pas
de données sur le HDD : docker et containerd échouent au boot, sans
nouvelle tentative. Diagnostic : `findmnt /mnt/appdata` puis
`systemctl status containerd docker`. Une panne du HDD devient une panne
de toute la pile : voir #206 et la surveillance SMART (#11).

## Conditions avant de commencer

- Être à côté du Pi, avec un créneau d'environ une heure, **hors de
  03:00-04:15** (sauvegardes nocturnes du Pi et copie vers le PC).
- Surveillance du boîtier USB terminée : #168 fermée, ou aucune erreur
  depuis la correction :

  ```bash
  sudo journalctl -k --since 2026-10-30 | grep -iE 'reset|I/O error|uas'   # attendu : rien
  ```

- HDD sain :

  ```bash
  sudo smartctl -H "$(readlink -f /dev/disk/by-label/bb-appdata)"
  ```

- Sauvegardes de la nuit présentes (une archive de moins de 24 h par
  service) :

  ```bash
  for d in ~/backups/*/ ~/vaultwarden-backups/; do ls -1t "$d" | head -n 1; done
  ```

  Ces sauvegardes ne couvrent pas les volumes nommés Docker
  (`docker volume ls`) : jusqu'au nettoyage, les dossiers `.old` en sont
  la seule copie de secours.

- Place libre sur le HDD d'au moins 1,5 fois la taille à copier :

  ```bash
  sudo du -shx /var/lib/containerd /var/lib/docker
  df -h /mnt/appdata
  ```

- Noter l'état de départ :

  ```bash
  docker ps --format '{{.Names}}' | sort > ~/docker-before.txt
  docker images --format '{{.Repository}}:{{.Tag}}' | sort > ~/images-before.txt
  docker inspect -f '{{.Name}} {{.HostConfig.RestartPolicy.Name}}' $(docker ps -aq)
  ```

  Tout conteneur en marche sans `unless-stopped` ni `always` devra être
  relancé à la main (`docker start`) après l'étape 7.

## Procédure

1. Première copie, à chaud (les services tournent encore) :

   ```bash
   sudo rsync -aHAXSx --numeric-ids /var/lib/containerd/ /mnt/appdata/containerd/
   sudo rsync -aHAXSx --numeric-ids /var/lib/docker/ /mnt/appdata/docker/
   ```

   Début de la coupure.

2. Arrêter Docker et containerd, puis vérifier qu'il ne reste rien :

   ```bash
   sudo systemctl stop docker.socket docker.service containerd.service
   systemctl is-active docker containerd                   # attendu : inactive, inactive
   pgrep -a containerd-shim                                # attendu : rien
   findmnt -rn -o TARGET | grep -E '^/var/lib/(docker|containerd)'   # attendu : rien
   ```

3. Seconde copie, qui ne reprend que les écarts, puis contrôle :

   ```bash
   sudo rsync -aHAXSx --numeric-ids --delete /var/lib/containerd/ /mnt/appdata/containerd/ && echo copy-ok
   sudo rsync -aHAXSx --numeric-ids --delete /var/lib/docker/ /mnt/appdata/docker/ && echo copy-ok
   sudo rsync -aHAXSx --numeric-ids --delete -n -i /var/lib/containerd/ /mnt/appdata/containerd/   # attendu : rien
   sudo rsync -aHAXSx --numeric-ids --delete -n -i /var/lib/docker/ /mnt/appdata/docker/           # attendu : rien
   sudo journalctl -k --since -1h | grep -iE 'reset|I/O error|sda'                                 # attendu : rien
   ```

   Deux `copy-ok`, rien d'autre : sinon, ne pas continuer, relancer
   simplement `sudo systemctl start containerd.service docker.service`.

4. Écrire la configuration **avant** de mettre les anciens dossiers de
   côté : un démarrage prématuré tombera ainsi sur la copie du HDD.

   ```bash
   sudo sed -i '1i root = "/mnt/appdata/containerd"' /etc/containerd/config.toml
   printf '{\n  "data-root": "/mnt/appdata/docker"\n}\n' | sudo tee /etc/docker/daemon.json
   sudo dockerd --validate --config-file /etc/docker/daemon.json
   sudo containerd config dump | grep '^root'          # attendu : root = "/mnt/appdata/containerd"
   sudo install -d /etc/systemd/system/containerd.service.d
   printf '[Unit]\nRequiresMountsFor=/mnt/appdata\n' | sudo tee /etc/systemd/system/containerd.service.d/appdata-mount.conf
   sudo systemctl daemon-reload
   ```

5. Mettre les anciens dossiers de côté, sans les supprimer :

   ```bash
   sudo mv -T /var/lib/containerd /var/lib/containerd.old
   sudo mv -T /var/lib/docker /var/lib/docker.old
   ```

6. Redémarrer containerd puis Docker. Les conteneurs en `unless-stopped`
   repartent seuls ; ceux arrêtés à la main (comme `bb-homelab-cloudflared`
   aujourd'hui) restent arrêtés. Fin de la coupure.

   ```bash
   sudo systemctl start containerd.service docker.service
   ```

7. Tunnel n8n, seulement s'il tournait avant : un redémarrage de Docker lui
   donne une nouvelle adresse `trycloudflare`. Suivre la rotation décrite
   dans [AUDIT.md](../docs/security/AUDIT.md) (nouvelle adresse dans
   `WEBHOOK_URL` et `N8N_HOST`, n8n recréé, moniteur Kuma repointé).

## Vérifier

```bash
docker info --format '{{.DockerRootDir}}'                       # attendu : /mnt/appdata/docker
sudo containerd config dump | grep '^root'                      # attendu : /mnt/appdata/containerd
sudo test ! -e /var/lib/containerd -a ! -e /var/lib/docker && echo sd-clean
docker images --format '{{.Repository}}:{{.Tag}}' | sort | diff - ~/images-before.txt && echo images-ok
docker ps --format '{{.Names}}' | sort | diff - ~/docker-before.txt && echo containers-ok
df -h / /mnt/appdata
```

- `sd-clean`, `images-ok` et `containers-ok`.
- Uptime Kuma vert, sauf le moniteur du tunnel s'il est arrêté ou en cours
  de rotation ; Home Assistant répond, une automatisation testée.
- `/` ne baisse qu'au nettoyage : les dossiers `.old` sont encore sur la SD.
- Noter la date d'exécution dans `PROJECT_LOG.md` (départ des sept jours).

## Retour arrière

**Le jour même** (rien d'important écrit depuis l'étape 6), si un contrôle
échoue et ne se corrige pas en quelques minutes :

```bash
sudo systemctl stop docker.socket docker.service containerd.service
sudo rm /etc/docker/daemon.json
sudo sed -i '/^root = "\/mnt\/appdata\/containerd"$/d' /etc/containerd/config.toml
grep -c '^root' /etc/containerd/config.toml       # attendu : 0
sudo mv -T /var/lib/containerd.old /var/lib/containerd
sudo mv -T /var/lib/docker.old /var/lib/docker
sudo systemctl start containerd.service docker.service
```

Si `mv -T` répond `Directory not empty`, un dossier a été recréé sur la SD :
le renommer en `*.failed`, puis relancer le `mv`. Échec avant l'étape 5 :
il n'y a pas de `.old`, seules les lignes `daemon.json` et `config.toml`
sont à retirer. Le drop-in de containerd peut rester.

**Les jours suivants** : les `.old` sont périmés (volumes nommés, nouvelles
images). Revenir en arrière en recopiant le HDD vers la SD, démons
arrêtés : `sudo rsync -aHAXSx --numeric-ids --delete /mnt/appdata/containerd/ /var/lib/containerd.old/`
(idem pour `docker`), puis les commandes ci-dessus.

## Nettoyage, une semaine plus tard

Après sept jours sans incident, et sur décision du propriétaire :

1. Garde-fou, puis suppression des anciens dossiers. C'est cette étape qui
   libère la carte SD :

   ```bash
   findmnt /mnt/appdata && docker info --format '{{.DockerRootDir}}' | grep -qx /mnt/appdata/docker && echo safe
   sudo rm -rf /var/lib/containerd.old /var/lib/docker.old    # seulement après « safe »
   df -h /    # attendu : nettement sous 80 %
   ```

2. Supprimer le volume orphelin `bb-homelab-n8n-data` (ancien volume de
   n8n, inutilisé depuis la migration vers le HDD, #93), après deux
   contrôles :

   ```bash
   docker inspect -f '{{range .Mounts}}{{.Source}} {{end}}' bb-homelab-n8n   # attendu : /mnt/appdata/n8n
   docker ps -a --filter volume=bb-homelab-n8n-data --format '{{.Names}}'    # attendu : rien
   docker volume rm bb-homelab-n8n-data
   ```

3. Installer l'alerte de remplissage (PR #212, `storage/DISK-ALERT.md`),
   dont la condition d'installation est `/` sous 80 %.
