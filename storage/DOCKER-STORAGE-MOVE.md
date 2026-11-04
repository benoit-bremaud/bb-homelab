# Déplacer le stockage Docker sur le HDD

Procédure pour sortir les images et les conteneurs de la carte SD et les
placer sur le disque des données `/mnt/appdata` (issue #202, étape 2).
Elle arrête tous les conteneurs, Home Assistant compris, pendant environ
15 minutes, sans redémarrer le Pi.

## Pourquoi deux dossiers

Docker 29 utilise ici le stockage d'images de containerd (`docker info` :
`driver-type io.containerd.snapshotter.v1`). Les images et leurs couches
sont alors dans `/var/lib/containerd`, pas dans `/var/lib/docker`. La
documentation de Docker le précise : changer `data-root` ne déplace pas le
stockage de containerd. Il faut donc déplacer les deux :

| Dossier sur la SD | Contenu | Réglage |
|---|---|---|
| `/var/lib/containerd` | images, couches, instantanés | `root` dans `/etc/containerd/config.toml` |
| `/var/lib/docker` | conteneurs, volumes, réseaux | `data-root` dans `/etc/docker/daemon.json` |

Docker attend déjà le HDD au démarrage (drop-in
`/etc/systemd/system/docker.service.d/appdata-mount.conf`,
`RequiresMountsFor=/mnt/appdata`). containerd reçoit le même drop-in.

## Conséquence à accepter

Sans le HDD, plus aucun conteneur ne démarre, y compris ceux qui n'ont pas
de données sur le HDD. C'est déjà presque le cas aujourd'hui : Docker
attend le HDD, et la plupart des services y gardent leurs données. Une
panne du HDD devient une panne de toute la pile : voir #206 et la
surveillance SMART (#11).

## Conditions avant de commencer

- Être à côté du Pi, avec un créneau d'environ 30 minutes.
- Sauvegardes de la nuit présentes et à jour (`ls -lt ~/backups/*/ | head`).
- HDD sain : `sudo smartctl -H /dev/sda` (le boîtier doit le permettre).
- Place libre sur le HDD supérieure à deux fois la taille à copier :

  ```bash
  sudo du -sh /var/lib/containerd /var/lib/docker
  df -h /mnt/appdata
  ```

- Noter l'état de départ pour la vérification finale :

  ```bash
  docker ps --format '{{.Names}} {{.Status}}' | sort > ~/docker-before.txt
  docker images --format '{{.Repository}}:{{.Tag}}' | sort > ~/images-before.txt
  ```

## Procédure

0. Supprimer le volume orphelin `bb-homelab-n8n-data` (ancien volume de
   n8n sur la SD, inutilisé depuis la migration vers le HDD, #93), après
   avoir vérifié que n8n tourne sur le HDD et que plus aucun conteneur ne
   l'utilise :

   ```bash
   docker inspect -f '{{range .Mounts}}{{.Source}} {{end}}' bb-homelab-n8n   # attendu : /mnt/appdata/n8n/…
   docker ps -a --filter volume=bb-homelab-n8n-data --format '{{.Names}}'    # attendu : rien
   docker volume rm bb-homelab-n8n-data
   ```

   Suppression définitive : seulement sur confirmation, et si les deux
   contrôles donnent le résultat attendu.

1. Arrêter Docker et containerd (les conteneurs s'arrêtent avec) :

   ```bash
   sudo systemctl stop docker.socket docker.service containerd.service
   systemctl is-active docker containerd   # attendu : inactive, inactive
   ```

2. Copier les deux dossiers sur le HDD, en gardant droits, liens et
   attributs étendus :

   ```bash
   sudo rsync -aHAXS --numeric-ids /var/lib/containerd/ /mnt/appdata/containerd/
   sudo rsync -aHAXS --numeric-ids /var/lib/docker/ /mnt/appdata/docker/
   ```

3. Mettre les anciens dossiers de côté, sans les supprimer (retour
   arrière) :

   ```bash
   sudo mv /var/lib/containerd /var/lib/containerd.old
   sudo mv /var/lib/docker /var/lib/docker.old
   ```

4. Pointer containerd vers le HDD : ajouter en tête de
   `/etc/containerd/config.toml`, avant toute section `[...]` :

   ```toml
   root = "/mnt/appdata/containerd"
   ```

5. Pointer Docker vers le HDD, dans `/etc/docker/daemon.json` (le fichier
   n'existe pas encore) :

   ```json
   {
     "data-root": "/mnt/appdata/docker"
   }
   ```

6. Faire attendre le HDD à containerd :

   ```bash
   sudo install -d /etc/systemd/system/containerd.service.d
   printf '[Unit]\nRequiresMountsFor=/mnt/appdata\n' | sudo tee /etc/systemd/system/containerd.service.d/appdata-mount.conf
   sudo systemctl daemon-reload
   ```

7. Redémarrer containerd puis Docker. Les conteneurs en `unless-stopped`
   repartent seuls :

   ```bash
   sudo systemctl start containerd.service docker.service
   ```

## Vérifier

```bash
docker info --format '{{.DockerRootDir}}'          # attendu : /mnt/appdata/docker
sudo du -sh /mnt/appdata/containerd /mnt/appdata/docker
docker images --format '{{.Repository}}:{{.Tag}}' | sort | diff - ~/images-before.txt && echo images-ok
docker ps --format '{{.Names}} {{.Status}}' | sort
df -h / /mnt/appdata
```

- Les mêmes images qu'avant (`images-ok`).
- Les mêmes conteneurs en `Up` qu'avant (comparer à `~/docker-before.txt`).
- Uptime Kuma tout vert, Home Assistant répond, une automatisation testée.
- `/` ne baisse qu'après l'étape de nettoyage : les dossiers `.old` sont
  encore sur la SD.

## Retour arrière

Si un contrôle échoue et ne se corrige pas en quelques minutes :

```bash
sudo systemctl stop docker.socket docker.service containerd.service
sudo rm /etc/docker/daemon.json
sudo sed -i '/^root = "\/mnt\/appdata\/containerd"$/d' /etc/containerd/config.toml
sudo mv /var/lib/containerd.old /var/lib/containerd
sudo mv /var/lib/docker.old /var/lib/docker
sudo systemctl start containerd.service docker.service
```

Le drop-in de containerd peut rester : il ne change rien tant que le HDD
est monté. Les copies sur le HDD (`/mnt/appdata/containerd`,
`/mnt/appdata/docker`) ne servent plus et se suppriment ensuite.

## Nettoyage, une semaine plus tard

Après sept jours sans incident, et seulement sur confirmation, supprimer
les anciens dossiers. C'est cette étape qui libère la carte SD :

```bash
sudo rm -rf /var/lib/containerd.old /var/lib/docker.old
df -h /    # attendu : nettement sous 80 %
```

Puis installer l'alerte de remplissage ([DISK-ALERT.md](DISK-ALERT.md)),
dont la condition d'installation est `/` sous 80 %.
