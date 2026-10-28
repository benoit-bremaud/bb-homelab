# Audit de sécurité du homelab — 2026-10-23

- **Statut** : v2, clôturé le 2026-10-24 (issue #46) : étapes 1 à 7 de §5.1
  faites, risques restants reportés en issues (§5.2). Le tableau de §2
  garde le relevé du 2026-10-23 ; la colonne « Après #46 » donne l'état final
- **Périmètre** : le Pi 5 `bb-homelab` (hôte, réseau, conteneurs,
  sauvegardes) et le dépôt (CI, secrets). Les trois conteneurs de la
  pile domotique (`~/home-assistant`) sont inventoriés mais hors
  périmètre de correction : ils ne vivent pas dans ce dépôt.
- **Méthode** : relevé sans modification (`ssh`, `docker inspect`,
  `apt list`, `ss`, `df`), confronté aux versions amont publiées et à
  deux référentiels : CIS Benchmark Debian 12/13 (sections accès,
  mises à jour, journalisation) et OWASP Docker Security Cheat Sheet
  (utilisateur, capacités, surface, images épinglées). Les relevés
  qui exigent `sudo` sont listés en §6 et intégrés à mesure.
- **Cotation** : chaque risque reçoit une **vraisemblance** V (1 rare →
  5 quasi certain) et un **impact** I (1 gêne → 5 perte de données ou
  compromission). Score = V × I sur 25. P1 ≥ 15, P2 ≥ 9, P3 ≥ 5,
  P4 en dessous.

## 1. Contrôles en place (ce qui protège déjà)

| Domaine | Contrôle | Preuve relevée |
|---|---|---|
| Réseau | Accès distant par Tailscale ; **vérifié le 2026-10-24** : aucune joignabilité depuis Internet hors tunnel cloudflared de n8n (box 5G sans IPv4 publique, ni redirection de port, ni DMZ, ni UPnP ; IPv6 entrant bloqué) | `tailscale status` : nœud `<pi-tailnet-ip>` ; UFW `deny incoming` par défaut, règles `22/tcp ALLOW IN Anywhere` et, depuis le 2026-10-28, `8123/tcp ALLOW IN <nest-ip>` (#162, §6). Côté WAN : test externe et lecture de la box en §6 (R10) |
| Réseau | UFW actif et activé au démarrage | `systemctl is-active ufw` → `active`, `is-enabled` → `enabled` |
| Hôte | SSH par clé, root interdit, pas de clavier interactif | `PermitRootLogin no`, `KbdInteractiveAuthentication no` ; 0 échec d'authentification en 7 jours |
| Hôte | Mises à jour de sécurité Debian automatiques, sans reboot automatique | `52unattended-upgrades-bb-homelab`, dernier passage 2026-10-23 06:57 |
| Hôte | Horloge synchronisée | `timedatectl` : NTP actif, synchronisé |
| Hôte | Données applicatives hors SD, montage par UUID avec `nofail` | `/mnt/appdata` sur `sda1` (pont USB-SATA JMS578, SMART lisible) |
| Conteneurs | Aucun conteneur privilégié, aucun `docker.sock` monté, aucune capacité ajoutée | `docker inspect` des 10 conteneurs |
| Conteneurs | Healthcheck sur 6 des 7 conteneurs du dépôt ; cloudflared n'en a pas (demande amont ouverte, cloudflared#1268) : le seul tunnel vers Internet reste « Up » même tombé (voir R2) | `docker ps` : 6 `healthy`, cloudflared `Up` sans état |
| Conteneurs | Services internes derrière Caddy (TLS, CA locale), n8n lié à `127.0.0.1` mais relayé vers Internet par le tunnel cloudflared (R6) | Caddyfile : 5 routes `*.bb-homelab.local` ; `127.0.0.1:5678` |
| Services | Vaultwarden : inscriptions et invitations fermées, jeton admin défini | `SIGNUPS_ALLOWED=false`, `INVITATIONS_ALLOWED=false` |
| Services | Mosquitto : anonyme refusé, fichier de mots de passe | `allow_anonymous false`, `password_file` |
| Sauvegardes | n8n et Vaultwarden archivés chaque nuit, battement de cœur Uptime Kuma, copie tirée vers le PC | cron 03:00 / 03:05, moniteurs push (#133) |
| Dépôt | Secrets jamais versionnés, gitleaks en CI, dépôt public contrôlé | 8 workflows : gitleaks, codeql, dependency-review, scorecard, 4 linters |

## 2. Inventaire des versions

Relevé du 2026-10-23 contre la dernière version publiée sur GitHub.

| Composant | En production | Dernière publiée | Écart | Après #46 |
|---|---|---|---|---|
| Debian | 13 trixie, 127 paquets en attente | — | dernière mise à jour manuelle : 2026-04-22 | 0 paquet en attente (étape 6) |
| Noyau | 6.12.47+rpt-rpi-2712 | 6.18.50 (paquet `linux-image-rpi-2712`) | reboot nécessaire | 6.18.50 actif après reboot |
| OpenSSH | 10.0p1-7+deb13u2 | 10.0p1-7+deb13u4 | correctifs stable | à jour (étape 6) |
| OpenSSL | 3.5.7-1~deb13u3 | 3.5.7-1~deb13u3+rpt1 | correctif | à jour (étape 6) |
| sudo / systemd | 1.9.16p2 u1 / 257.9 | u2 / 257.13 | correctifs stable | à jour (étape 6) |
| Docker CE / Compose / containerd | 29.4.0 / v5.1.2 / 2.2.2 | 29.9.2 / 5.6.1 / 2.4.2 | dépôt tiers, jamais auto | 29.9.2 / 5.6.1 / 2.4.2 (étape 6) |
| Tailscale | 1.102.2 | 1.104.2 | dépôt tiers, jamais auto | 1.104.2 (étape 6) |
| caddy | 2.8.4 | 2.11.7 (2026-10-03) | 3 mineures | 2.11.7 (PR #154) |
| vaultwarden/server | 1.36.0 | 1.37.4 (2026-10-05) | 1 mineure | 1.37.4 (PR #148) |
| louislam/uptime-kuma | 2.3.2 | 2.5.7 (2026-10-23) | 2 mineures | 2.5.7 (PR #157) |
| gethomepage/homepage | v1.13.2 | v2.6.0 (2026-10-17) | **majeure** | v2.7.0 (PR #157) |
| jellyfin/jellyfin | 10.11.9 | v12.3 (2026-10-23) | **deux majeures** | inchangé, reporté (#142) |
| n8nio/n8n | tag `latest` (= 2.16.0, image du 2026-04-07) | 2.44.6 (2026-10-22) | 28 mineures, tag flottant | 2.44.6 épinglé (PR #150) |
| cloudflare/cloudflared | 2024.8.3 | 2026.10.3 (2026-10-21) | 26 mois de publications | 2026.10.3 (PR #150) |
| home-assistant (hors dépôt) | 2026.6.2 | 2026.10.2 | 4 mois | hors périmètre (#26) |
| zigbee2mqtt (hors dépôt) | 2.12.0 | 2.14.2 | 2 mineures | hors périmètre (#26) |
| eclipse-mosquitto (hors dépôt) | 2.1.2-alpine | — | pas de release GitHub ; à vérifier sur Docker Hub dans l'issue R12 | hors périmètre (#26) |

## 3. Posture des conteneurs

| Conteneur | Utilisateur | Ports hôte | Durcissement | Données |
|---|---|---|---|---|
| bb-homelab-caddy | root (défaut image) | 80, 443 tcp+udp sur 0.0.0.0 | aucun | `/mnt/appdata/caddy` (PKI de la CA locale, **non sauvegardée**) |
| bb-homelab-vaultwarden | root | aucun (Caddy seul) | aucun | `/mnt/appdata/vaultwarden`, sauvegardé |
| bb-homelab-uptime-kuma | root | aucun | aucun | `/mnt/appdata/uptime-kuma`, **non sauvegardé** |
| bb-homelab-homepage | root (explicite) | aucun | aucun | config versionnée dans le dépôt |
| bb-homelab-jellyfin | root | **8096 sur 0.0.0.0** en plus de la route Caddy (voulu : clients TV et mobiles sans la CA locale, ADR 0003) | aucun | `/mnt/appdata/jellyfin`, **non sauvegardé** (#138) |
| bb-homelab-n8n | `node` | 127.0.0.1:5678, exposé à Internet via le tunnel | aucun | `/mnt/appdata/n8n`, sauvegardé |
| bb-homelab-cloudflared | `nonroot` | réseau hôte | aucun | — |
| homeassistant | root | réseau hôte (8123) | aucun | `/mnt/appdata/homeassistant`, non sauvegardé |
| zigbee2mqtt | root | 127.0.0.1:8080 | aucun | `/mnt/appdata/zigbee2mqtt`, non sauvegardé |
| mosquitto | root → `mosquitto` interne | 1883 sur 0.0.0.0 | aucun | `/mnt/appdata/mosquitto`, non sauvegardé |

« Aucun » durcissement signifie : pas de `no-new-privileges`, pas de
`cap_drop: [ALL]`, pas de rootfs en lecture seule. L'audit détaillé
utilisateur par utilisateur est l'objet de l'issue #131.

## 4. Risques classés

| ID | Constat | V | I | Score | Priorité |
|---|---|---|---|---|---|
| R1 | **Résolu le 2026-10-24 (étape 6, §6.2), récurrence dans #140** : 127 paquets apt en retard de six mois, dont OpenSSH, OpenSSL, sudo, systemd, noyau ; `unattended-upgrades` ne couvre que `Debian-Security`, jamais les point-releases stable ni les dépôts docker / tailscale / raspberrypi | 4 | 4 | 16 | **P1** |
| R2 | **Version et supervision résolues le 2026-10-24 (PR #150, cloudflared 2026.10.3 ; moniteur HTTPS Uptime Kuma sur l'URL publique, repointé à chaque rotation, §6.2) ; hostname stable dans #143** : `cloudflared` 2024.8.3 : seule porte d'entrée depuis Internet, **confirmé** par le test WAN de l'étape 2 (§6 : ports publiés par Docker et SSH injoignables depuis Internet), et pas seul composant exposé : le tunnel relaie le trafic public vers n8n (`127.0.0.1:5678`, voir R6) ; deux ans de correctifs manquants, et aucune supervision du tunnel (un tunnel tombé n'est signalé par personne ; l'image officielle est distroless, sans shell ni `curl`, donc un `healthcheck` Compose n'a rien pour s'exécuter) | 4 | 4 | 16 | **P1** |
| R3 | **Atténué le 2026-10-24 (étape 2, §6.1)** : carte SD passée de 94 % à 64 % (environ 10 Go libres) après suppression de 4 images inutilisées, de `.platformio` et du swap orphelin `/var/swap`. Le risque résiduel reste la croissance des images et des données sur une SD : un disque plein pendant un `apt full-upgrade` ou un `docker pull` peut faire échouer la mise à jour ou corrompre des bases SQLite ; décision SD → SSD : #29 (P2) | 2 | 3 | 6 | P3 |
| R4 | **Résolu le 2026-10-24 (PR #154, Caddy 2.11.7)** : Caddy 2.8.4 : terminaison TLS et CA locale de tous les services, trois versions mineures de retard | 3 | 4 | 12 | P2 |
| R5 | **Résolu le 2026-10-24 (PR #148, Vaultwarden 1.37.4)** : Vaultwarden 1.36.0 : coffre de mots de passe, une version mineure de retard ([notes de version 1.37.x](https://github.com/dani-garcia/vaultwarden/releases)) | 2 | 5 | 10 | P2 |
| R6 | **Résolu le 2026-10-24 (PR #150, n8n 2.44.6 épinglé)** : n8n sur le tag `latest` (`.env` du Pi) : déploiement non reproductible, 28 versions mineures de retard sur un service qui tient des identifiants d'API **et qui traite du trafic Internet** dès que le tunnel cloudflared tourne (URL trycloudflare aléatoire, authentification n8n : la surface est publique, pas confidentielle) ; une compromission livre les identifiants des services tiers qu'il orchestre | 4 | 4 | 16 | **P1** |
| R7 | PKI Caddy (CA locale) et données Uptime Kuma hors sauvegarde : perdre la CA oblige à re-faire confiance sur chaque client ; perdre Kuma efface moniteurs, notifications et historique | 3 | 3 | 9 | P2 |
| R8 | Cinq des sept conteneurs du dépôt tournent root sans `no-new-privileges` ni `cap_drop` : une faille applicative donne root dans le conteneur (recoupe #131) | 2 | 4 | 8 | P3 |
| R9 | **Kuma et Homepage résolus le 2026-10-24 (PR #157), Jellyfin dans #142** : Uptime Kuma, Homepage, Jellyfin en retard, dont deux sauts de version majeure ; Jellyfin 12 change le schéma de base sans retour arrière possible, et ses données ne sont pas sauvegardées | 3 | 2 | 6 | P3 |
| R10 | Les ports publiés par Docker (80/443 Caddy, 8096 Jellyfin voulu par l'ADR 0003, 1883 Mosquitto) **contournent UFW** : Docker écrit ses propres règles iptables dans la chaîne `FORWARD`, que UFW ne filtre pas ; la règle `deny incoming` ne protège donc que les services en réseau hôte (8123 Home Assistant, sauf depuis la Nest Mini autorisée le 2026-10-28 par #162 ; go2rtc 18555) ; SSH est lui ouvert par la règle `22/tcp ALLOW IN Anywhere`. Exposition LAN confirmée ; exposition Internet **écartée** en TCP par le test externe de §6 (étape 2, 2026-10-24 ; UDP/443 en IPv6 déduit, non sondé, suivi dans #139) : le risque reste interne au LAN et à toute future box qui ouvrirait des ports | 3 | 3 | 9 | P2 |
| R11 | Aucun scan d'image ni Dependabot sur les images compose (#90, #130) : les retards de §2 ne sont détectés que par un audit manuel | 3 | 2 | 6 | P3 |
| R12 | Trois conteneurs hors dépôt (`~/home-assistant`) : ni épinglage suivi, ni sauvegarde, ni revue | 2 | 2 | 4 | P4 |
| R13 | AppArmor installé mais désactivé au boot ; fail2ban et auditd absents ; `X11Forwarding yes` inutile ; SSH autorisé depuis `Anywhere` alors que `harden-ssh.sh` offre `SSH_UFW_SCOPE=tailscale` (clé seule et mot de passe refusé, donc faible) | 1 | 2 | 2 | P4 |
| R14 | `benoit` membre du groupe `docker` (équivalent root) : accepté, utilisateur unique, clé SSH seule | 1 | 2 | 2 | accepté |

## 5. Feuille de route

### 5.1 Dans la brique #46 (une PR ou une opération par ligne, validée à chaque étape)

| Étape | Risques | Action | Garde-fous |
|---|---|---|---|
| 1 | — | Cet audit (`docs/security/AUDIT.md`) | PR `Refs #46` |
| 2 | R10, R3 | D'abord le relevé IPv6 puis le test de joignabilité depuis Internet, IPv4 et IPv6, TCP et UDP/443, selon le protocole de §6 (par le propriétaire depuis la 4G, résultat consigné dans §6 et dans #139) : le report de R10 vers #139 n'est confirmé que si tout est fermé ; sinon R10 repasse en P1 et se traite avant toute mise à jour. Puis libérer la SD : supprimer les 4 images inutilisées (n8n 1.97.1, alpine, curl, hello-world : 1,45 Go), `apt clean`, trancher le doublon de swap, décider du sort de `.platformio` | lecture de `/proc/swaps` avant toute suppression ; aucune image utilisée par un conteneur n'est touchée. **Condition de sortie : `df` sous 80 % sur la SD**, car les étapes 3 à 5 tirent de nouvelles images en gardant les anciennes pour le retour arrière et R3 identifie le disque plein pendant un `docker pull` comme risque de corruption ; si les 1,45 Go d'images ne suffisent pas (94 % → environ 89 %), `.platformio` et `/var/swap` cessent d'être optionnels, ou la migration SSD (#29) passe avant toute mise à jour |
| 3 | R2, R6, R4 | La surface Internet d'abord : cloudflared 2026.10.3 (la porte confirmée) et n8n 2.44.6 à la place de `latest` dans le `.env` du Pi et le compose (la cible du tunnel), puis Caddy 2.11.7 (TLS de tout le reste) ; compose + `.env.example`, `up -d`, QA des cinq routes ; superviser le tunnel par un moniteur HTTPS Uptime Kuma sur l'URL publique de n8n (bout en bout : tunnel et n8n, alerte Telegram), et non par un `healthcheck` Compose, inexécutable dans l'image distroless (ni shell ni `curl`) ; le moniteur est mis à jour à chaque rotation d'URL jusqu'à #143 | sauvegarde manuelle n8n avant, notes de migration n8n 2.16 → 2.44 lues, notes de version lues. Avant le tag Caddy : archive à froid (`docker compose stop caddy`) de `/mnt/appdata/caddy/data` (PKI, CA racine) et `/mnt/appdata/caddy/config`, vérifiée (listing de l'archive, fichiers de la CA racine présents) : c'est la première copie de la PKI (R7). Retour arrière : cloudflared = ancien tag (sans état) ; Caddy = arrêt, restauration de l'archive, ancien tag, démarrage ; n8n = arrêt de la pile, **ancien tag remis d'abord** dans le `.env` du Pi et le compose, puis la procédure de restauration de `services/n8n/BACKUP.md` sur l'archive prise juste avant (son `docker compose up -d` final démarre alors l'ancienne version sur la base restaurée) ; jamais l'ancien tag seul sur une base migrée (`bootstrap/FIRSTBOOT.md`), ni la restauration avec le nouveau tag encore épinglé. Après : la recréation de cloudflared change l'URL trycloudflare, donc relever le nouveau hostname dans les journaux, le reporter dans `WEBHOOK_URL` et `N8N_HOST` du `.env` du Pi, recréer n8n, repointer le widget Impropedia (dépôt impropedia), puis test webhook de bout en bout ; connexion n8n vérifiée. Cause de la rotation traitée en #143 (§5.2) |
| 4 | R5 | Vaultwarden 1.37.4 | sauvegarde manuelle avant, notes de version lues, connexion au coffre vérifiée après. Retour arrière si la connexion échoue : arrêt de la pile, restauration de l'archive prise juste avant (procédure `services/vaultwarden/BACKUP.md`, même version), ancien tag remis dans le compose **avant** le démarrage, puis `up -d` ; jamais l'ancien tag seul sur une base déjà migrée, ni la restauration avec le nouveau tag encore épinglé |
| 5 | R9, R7 (partiel) | Uptime Kuma 2.5.7 ; Homepage v2.6.0 après lecture du guide de migration v2 (config versionnée dans le dépôt, retour arrière = `git checkout` + ancien tag). Jellyfin est sorti de cette étape : deux majeures et un schéma non réversible, migration dédiée #142 | sauvegarde Kuma à froid avant, selon la procédure amont de migration v1 → v2 : `docker compose stop uptime-kuma`, archive datée de `/mnt/appdata/uptime-kuma`, contrôle de l'archive (`sqlite3 kuma.db "PRAGMA integrity_check"` sur la copie, à défaut taille et liste des fichiers), puis changement de tag et `up -d`. Retour arrière : arrêt, restauration de l'archive, ancien tag, démarrage. C'est la première copie des données Kuma, comme l'étape 3 fait la première copie de la PKI Caddy ; l'automatisation des deux reste en §5.2 (#138) |
| 6 | R1 | `sudo apt full-upgrade` lancé par le propriétaire (`ssh -t`), **sans reboot** tant qu'il n'est pas à côté du Pi ; le noyau 6.18 attend ce reboot | `df` avant, SD sous 80 % ; `docker compose ps` après |
| 7 | — | Issues de report (§5.2), fermeture de #46, journal | — |

### 5.2 Reporté en issues

| Risque | Issue | Décision proposée |
|---|---|---|
| R7 (P2) | #138 | Étendre le script de sauvegarde et le battement de cœur de #133 ; reporté car il demande un script et un moniteur, pas un changement de tag. Les copies manuelles des étapes 3 (PKI Caddy) et 5 (Kuma) couvrent l'intervalle |
| R9 (Jellyfin) | #142 | Copie validée de `/mnt/appdata/jellyfin` avant toute tentative, notes 12.0 et 12.x lues, procédure de retour arrière écrite |
| R8 | #131 (passée P3) | Tableau utilisateur / capacités par service, `no-new-privileges` et `cap_drop` là où l'image le supporte |
| R10 (P2, report confirmé par le test WAN de l'étape 2) | #139 | Lier les ports publiés à une adresse (`127.0.0.1:` ou l'IP Tailscale) ou poser des règles `DOCKER-USER` ; réévaluer 8096 (ADR 0003) et 1883 ; reporté car il touche l'accès de tous les clients et demande une matrice |
| R2 / R6 (cause de la rotation d'URL) | #143 (P3) | Remplacer le tunnel rapide par un tunnel nommé à hostname stable : plus de `.env` ni de widget à repointer à chaque recréation de cloudflared ; matrice tunnel nommé / Tailscale Funnel / liste de contrôle |
| R11 | #90 et #130 (passées P3), #22 fermée (non planifiée) | Dependabot compose + Trivy hebdomadaire remplacent Watchtower |
| R1 (récurrence) | #140 | Soit ajouter `Debian` stable + dépôts tiers, soit un rappel mensuel ; ADR |
| R12 | #26 (reformulée) | Déplacer `~/home-assistant` sous `services/` avec épinglage et sauvegarde |
| Suivis des étapes 3 et 5 | #151, #152, #156 | `N8N_WEBHOOK_URL` à la place de `WEBHOOK_URL` déprécié (#151, P4) ; `allowedOrigins` sur le webhook n8n, qui reflète toute origine (#152, P3) ; porte d'authentification de Homepage v2 (#156, P4) |
| R13 | #141 | Ajouter `X11Forwarding no` à `harden-ssh.sh` ; relancer `SSH_UFW_SCOPE=tailscale` quand le propriétaire est près du Pi ; AppArmor et fail2ban évalués par matrice |

## 6. Relevés sudo (2026-10-23, lancés par le propriétaire)

Commandes :

```bash
sudo ufw status verbose
sudo sshd -T | grep -E "^(passwordauthentication|pubkeyauthentication|maxauthtries|allowusers|listenaddress|port) "
sudo cat /etc/ssh/sshd_config.d/50-cloud-init.conf
sudo ss -tulpn | grep -E ":(18555|18554|39295|63761) "
cat /proc/swaps
sudo du -sh /var/lib/docker /var/swap /swapfile
ip -6 addr show scope global
```

| Relevé | Résultat |
|---|---|
| Règles UFW effectives (R10, §1 Réseau) | `Status: active`, `Default: deny (incoming), allow (outgoing), deny (routed)`, au relevé du 2026-10-24, une seule règle : `22/tcp ALLOW IN Anywhere` (v4 et v6). **Depuis le 2026-10-28** (#162), deux règles : s'y ajoute `8123/tcp ALLOW IN <nest-ip>` (commentaire `Nest Mini fetches HA TTS audio`), la seule Nest Mini peut lire l'audio TTS de Home Assistant ; son adresse est réservée sur la box |
| SSH effectif (`sshd -T`) | `passwordauthentication no` (fixé par `50-cloud-init.conf`), `pubkeyauthentication yes`, `maxauthtries 6`, écoute `0.0.0.0:22` et `[::]:22`, pas d'`AllowUsers` |
| Sockets non identifiés | `127.0.0.1:39295` cloudflared (métriques), `127.0.0.1:18554` et `*:18555` go2rtc (flux vidéo Home Assistant, réseau hôte, donc bloqué par UFW), `<pi-tailnet-ip>:63761` tailscaled |
| Swaps actifs (`/proc/swaps`) | `/swapfile` 2 Go (priorité -2, 0 utilisé) et `/dev/zram0` 2 Go ; `/var/swap` n'est pas monté → orphelin |
| Tailles (`du`) | `/var/lib/docker` 8,5 Go, `/var/swap` 1,7 Go, `/swapfile` 2,1 Go |
| Adresse IPv6 globale du Pi (`ip -6 addr show scope global`) | **Relevé le 2026-10-23 : le Pi porte une adresse IPv6 globale** (préfixe /64 délégué par la box, dynamique, non reproduite ici). Les ports publiés par Docker sans adresse (`443:443`, `443:443/udp`) et sshd (`[::]:22`) écoutent donc aussi en IPv6 : le volet IPv6 du test ci-dessous est obligatoire, et le pare-feu IPv6 de la box est la seule protection en amont d'UFW |
| Joignabilité depuis Internet (R10, §1 Réseau) | **Fait le 2026-10-24 : rien n'est joignable depuis Internet.** IPv4 : l'adresse publique vue de l'extérieur, testée sur 22, 80, 443, 1883, 8096 et 8123 en TCP depuis plusieurs nœuds externes (check-host.net), répond « délai dépassé » partout ; un seul nœud a vu 1883 ouvert, non reproduit sur 15 autres nœuds et défaillant ensuite sur toute cible, donc écarté. IPv6 : un scanner externe (IPscan) lancé depuis le Pi vers sa propre adresse globale trouve les 105 ports testés furtifs (89 TCP, 16 UDP), seul le ping ICMPv6 répond ; 1883, 8096, 8123 et 22 ne figurent pas dans sa liste par défaut et ont été ajoutés comme ports personnalisés, les six ports TCP ci-dessus sont donc sondés directement. Interface de la box, lue par le propriétaire : box **5G** dont le WAN est en IPv6 seul (l'IPv4 sortante est traduite et partagée par l'opérateur, aucune connexion IPv4 entrante n'est donc possible), aucun menu de redirection de port, de DMZ ni d'UPnP. UDP/443 : exclu en IPv4 (aucune entrée IPv4 possible) ; en IPv6 il n'a **pas été sondé directement** (ni IPscan ni check-host ne le testent), seulement déduit du filtrage entrant constaté sur les 16 ports UDP testés : ce point résiduel est suivi dans #139. Un premier essai a été **invalidé** : l'agent de sécurité installé sur le poste de test intercepte toute connexion TCP sortante (un port quelconque d'un résolveur public paraît ouvert), d'où des scans faussement ouverts ; les tests retenus sont lancés depuis des serveurs externes |

### 6.1 Étape 2 : libération de la SD (2026-10-23)

| Action | Résultat |
|---|---|
| `docker image rm` des 4 images inutilisées (n8n 1.97.1, alpine, curl 8.10.1, hello-world) | supprimées ; aucune image utilisée par un conteneur touchée |
| `rm -rf ~/.platformio` (6 Go, inutilisé depuis 2026-06-17) | supprimé, décision du propriétaire |
| `sudo rm /var/swap` après lecture de `/proc/swaps` (non monté, absent de `fstab`, pas de `dphys-swapfile`) | supprimé, 1,7 Go rendus ; `/swapfile` et `zram0` inchangés |
| `sudo apt clean` | fait |
| `df -h /` | **92 % → 64 %** (18 Go / 29 Go) : condition de sortie de l'étape 2 (< 80 %) remplie |
| `docker ps` après coup | les 10 conteneurs présents. Observation hors périmètre : `zigbee2mqtt` redémarre en boucle depuis la recréation de la pile Home Assistant (coordinateur Zigbee réseau injoignable, `EHOSTUNREACH`), antérieur au nettoyage, traité dans #26 |

### 6.2 Étape 6 : mise à jour de l'hôte (2026-10-24)

| Action | Résultat |
|---|---|
| `sudo apt full-upgrade` lancé par le propriétaire dans `tmux`, par le réseau local | 127 paquets mis à jour, dont OpenSSH, OpenSSL, sudo, systemd, Docker 29.9.2, Tailscale 1.104.2 ; 0 paquet en attente ensuite |
| `sudo reboot`, propriétaire à côté du Pi | noyau 6.18.50 actif ; montage `/mnt/appdata` (UUID, `nofail`) revenu seul |
| Contrôle après reboot | tous les conteneurs du dépôt en bonne santé, les 5 sites Caddy répondent, SD à 71 % |
| URL du tunnel rapide | changée au redémarrage de Docker puis au reboot (#28, #143) ; `WEBHOOK_URL` et `N8N_HOST` mis à jour, n8n recréé, moniteur Kuma du tunnel repointé, tous deux en ligne |

## 7. Références

- Issue #46 (cette étude) ; issues de report #138, #139, #140, #141, #142, #143 et #26, #29, #131, #90, #130, #22 (voir §5.2) ; suivis #151, #152, #156 ; #133 (sauvegardes et battements de cœur)
- [ADR 0002 — reverse proxy Caddy](../decisions/0002-caddy-reverse-proxy.md),
  [ADR 0005 — Vaultwarden](../decisions/0005-vaultwarden-deployment.md)
- [bootstrap/harden-ssh.sh](../../bootstrap/harden-ssh.sh),
  [services/n8n/BACKUP.md](../../services/n8n/BACKUP.md)
- CIS Debian Linux Benchmark ; OWASP Docker Security Cheat Sheet
