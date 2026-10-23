# Audit de sécurité du homelab — 2026-10-23

- **Statut** : v1, inventaire en lecture seule du 2026-10-23 (issue #46)
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
| Réseau | Accès distant par Tailscale ; **hypothèse non vérifiée** : aucune redirection de port sur la box ni joignabilité depuis Internet (hors tunnel cloudflared de n8n) | `tailscale status` : nœud 100.121.134.61 ; UFW `deny incoming` par défaut, seule règle `22/tcp ALLOW IN Anywhere` (§6). Ces relevés ne prouvent rien côté WAN : test externe à faire (§6, R10) |
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

| Composant | En production | Dernière publiée | Écart |
|---|---|---|---|
| Debian | 13 trixie, 127 paquets en attente | — | dernière mise à jour manuelle : 2026-04-22 |
| Noyau | 6.12.47+rpt-rpi-2712 | 6.18.50 (paquet `linux-image-rpi-2712`) | reboot nécessaire |
| OpenSSH | 10.0p1-7+deb13u2 | 10.0p1-7+deb13u4 | correctifs stable |
| OpenSSL | 3.5.7-1~deb13u3 | 3.5.7-1~deb13u3+rpt1 | correctif |
| sudo / systemd | 1.9.16p2 u1 / 257.9 | u2 / 257.13 | correctifs stable |
| Docker CE / Compose / containerd | 29.4.0 / v5.1.2 / 2.2.2 | 29.9.2 / 5.6.1 / 2.4.2 | dépôt tiers, jamais auto |
| Tailscale | 1.102.2 | 1.104.2 | dépôt tiers, jamais auto |
| caddy | 2.8.4 | 2.11.7 (2026-10-03) | 3 mineures |
| vaultwarden/server | 1.36.0 | 1.37.4 (2026-10-05) | 1 mineure |
| louislam/uptime-kuma | 2.3.2 | 2.5.7 (2026-10-23) | 2 mineures |
| gethomepage/homepage | v1.13.2 | v2.6.0 (2026-10-17) | **majeure** |
| jellyfin/jellyfin | 10.11.9 | v12.3 (2026-10-23) | **deux majeures** |
| n8nio/n8n | tag `latest` (= 2.16.0, image du 2026-04-07) | 2.44.6 (2026-10-22) | 28 mineures, tag flottant |
| cloudflare/cloudflared | 2024.8.3 | 2026.10.3 (2026-10-21) | 26 mois de publications |
| home-assistant (hors dépôt) | 2026.6.2 | 2026.10.2 | 4 mois |
| zigbee2mqtt (hors dépôt) | 2.12.0 | 2.14.2 | 2 mineures |
| eclipse-mosquitto (hors dépôt) | 2.1.2-alpine | — | pas de release GitHub ; à vérifier sur Docker Hub dans l'issue R12 |

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
| R1 | 127 paquets apt en retard de six mois, dont OpenSSH, OpenSSL, sudo, systemd, noyau ; `unattended-upgrades` ne couvre que `Debian-Security`, jamais les point-releases stable ni les dépôts docker / tailscale / raspberrypi | 4 | 4 | 16 | **P1** |
| R2 | `cloudflared` 2024.8.3 : seule porte d'entrée depuis Internet, mais pas seul composant exposé : le tunnel relaie le trafic public vers n8n (`127.0.0.1:5678`, voir R6) ; deux ans de correctifs manquants, et aucun healthcheck (un tunnel tombé n'est pas détecté par Docker) | 4 | 4 | 16 | **P1** |
| R3 | Carte SD à 94 % (décision SD → SSD : #29, passée P2) (1,7 Go libres) : 8,5 Go sous `/var/lib/docker` (13,2 Go d'images déclarées, 1,45 Go récupérables), 6 Go de `.platformio` hors homelab, un fichier swap orphelin `/var/swap` (1,7 Go, inactif : seuls `/swapfile` et zram sont dans `/proc/swaps`) ; un `apt full-upgrade` ou un `docker pull` peut échouer ou corrompre des bases SQLite | 5 | 3 | 15 | **P1** |
| R4 | Caddy 2.8.4 : terminaison TLS et CA locale de tous les services, trois versions mineures de retard | 3 | 4 | 12 | P2 |
| R5 | Vaultwarden 1.36.0 : coffre de mots de passe, une version mineure de retard ([notes de version 1.37.x](https://github.com/dani-garcia/vaultwarden/releases)) | 2 | 5 | 10 | P2 |
| R6 | n8n sur le tag `latest` (`.env` du Pi) : déploiement non reproductible, 28 versions mineures de retard sur un service qui tient des identifiants d'API **et qui traite du trafic Internet** dès que le tunnel cloudflared tourne (URL trycloudflare aléatoire, authentification n8n : la surface est publique, pas confidentielle) ; une compromission livre les identifiants des services tiers qu'il orchestre | 4 | 4 | 16 | **P1** |
| R7 | PKI Caddy (CA locale) et données Uptime Kuma hors sauvegarde : perdre la CA oblige à re-faire confiance sur chaque client ; perdre Kuma efface moniteurs, notifications et historique | 3 | 3 | 9 | P2 |
| R8 | Cinq des sept conteneurs du dépôt tournent root sans `no-new-privileges` ni `cap_drop` : une faille applicative donne root dans le conteneur (recoupe #131) | 2 | 4 | 8 | P3 |
| R9 | Uptime Kuma, Homepage, Jellyfin en retard, dont deux sauts de version majeure ; Jellyfin 12 change le schéma de base sans retour arrière possible, et ses données ne sont pas sauvegardées | 3 | 2 | 6 | P3 |
| R10 | Les ports publiés par Docker (80/443 Caddy, 8096 Jellyfin voulu par l'ADR 0003, 1883 Mosquitto) **contournent UFW** : Docker écrit ses propres règles iptables dans la chaîne `FORWARD`, que UFW ne filtre pas ; la règle `deny incoming` ne protège donc que les services en réseau hôte (8123 Home Assistant, go2rtc 18555) ; SSH est lui ouvert par la règle `22/tcp ALLOW IN Anywhere`. Exposition LAN confirmée ; l'exposition Internet reste **non vérifiée** tant que le test externe de §6 n'est pas fait (étape 2) : ces ports sont traités comme potentiellement publics jusque-là | 3 | 3 | 9 | P2 |
| R11 | Aucun scan d'image ni Dependabot sur les images compose (#90, #130) : les retards de §2 ne sont détectés que par un audit manuel | 3 | 2 | 6 | P3 |
| R12 | Trois conteneurs hors dépôt (`~/home-assistant`) : ni épinglage suivi, ni sauvegarde, ni revue | 2 | 2 | 4 | P4 |
| R13 | AppArmor installé mais désactivé au boot ; fail2ban et auditd absents ; `X11Forwarding yes` inutile ; SSH autorisé depuis `Anywhere` alors que `harden-ssh.sh` offre `SSH_UFW_SCOPE=tailscale` (clé seule et mot de passe refusé, donc faible) | 1 | 2 | 2 | P4 |
| R14 | `benoit` membre du groupe `docker` (équivalent root) : accepté, utilisateur unique, clé SSH seule | 1 | 2 | 2 | accepté |

## 5. Feuille de route

### 5.1 Dans la brique #46 (une PR ou une opération par ligne, validée à chaque étape)

| Étape | Risques | Action | Garde-fous |
|---|---|---|---|
| 1 | — | Cet audit (`docs/security/AUDIT.md`) | PR `Refs #46` |
| 2 | R10, R3 | D'abord le relevé IPv6 puis le test de joignabilité depuis Internet, IPv4 et IPv6, TCP et UDP/443, selon le protocole de §6 (par le propriétaire depuis la 4G, résultat consigné dans §6 et dans #139) : le report de R10 vers #139 n'est confirmé que si tout est fermé ; sinon R10 repasse en P1 et se traite avant toute mise à jour. Puis libérer la SD : supprimer les 4 images inutilisées (n8n 1.97.1, alpine, curl, hello-world : 1,45 Go), `apt clean`, trancher le doublon de swap, décider du sort de `.platformio` | lecture de `/proc/swaps` avant toute suppression ; aucune image utilisée par un conteneur n'est touchée |
| 3 | R2, R6, R4 | La surface Internet d'abord : cloudflared 2026.10.3 (la porte) et n8n 2.44.6 à la place de `latest` dans le `.env` du Pi et le compose (la cible du tunnel), puis Caddy 2.11.7 (TLS de tout le reste) ; compose + `.env.example`, `up -d`, QA des cinq routes ; ajouter une sonde cloudflared (`--metrics 127.0.0.1:<port>` + healthcheck sur `/ready`) | sauvegarde manuelle n8n avant, notes de migration n8n 2.16 → 2.44 lues, notes de version lues, retour arrière = ancien tag ; URL du tunnel et connexion n8n vérifiées après |
| 4 | R5 | Vaultwarden 1.37.4 | sauvegarde manuelle avant, notes de version lues, connexion au coffre vérifiée après |
| 5 | R9, R7 (partiel) | Uptime Kuma 2.5.7 ; Homepage v2.6.0 après lecture du guide de migration v2 (config versionnée dans le dépôt, retour arrière = `git checkout` + ancien tag). Jellyfin est sorti de cette étape : deux majeures et un schéma non réversible, migration dédiée #142 | sauvegarde Kuma manuelle avant : première copie des données Kuma, la PKI Caddy et l'automatisation restent en §5.2 |
| 6 | R1 | `sudo apt full-upgrade` lancé par le propriétaire (`ssh -t`), **sans reboot** tant qu'il n'est pas à côté du Pi ; le noyau 6.18 attend ce reboot | `df` avant, SD sous 80 % ; `docker compose ps` après |
| 7 | — | Issues de report (§5.2), fermeture de #46, journal | — |

### 5.2 Reporté en issues

| Risque | Issue | Décision proposée |
|---|---|---|
| R7 (P2) | #138 | Étendre le script de sauvegarde et le battement de cœur de #133 ; reporté car il demande un script et un moniteur, pas un changement de tag |
| R9 (Jellyfin) | #142 | Copie validée de `/mnt/appdata/jellyfin` avant toute tentative, notes 12.0 et 12.x lues, procédure de retour arrière écrite |
| R8 | #131 (passée P3) | Tableau utilisateur / capacités par service, `no-new-privileges` et `cap_drop` là où l'image le supporte |
| R10 (P2, report conditionné au test WAN de l'étape 2) | #139 | Lier les ports publiés à une adresse (`127.0.0.1:` ou l'IP Tailscale) ou poser des règles `DOCKER-USER` ; réévaluer 8096 (ADR 0003) et 1883 ; reporté car il touche l'accès de tous les clients et demande une matrice |
| R11 | #90 et #130 (passées P3), #22 à fermer | Dependabot compose + Trivy hebdomadaire remplacent Watchtower |
| R1 (récurrence) | #140 | Soit ajouter `Debian` stable + dépôts tiers, soit un rappel mensuel ; ADR |
| R12 | #26 (reformulée) | Déplacer `~/home-assistant` sous `services/` avec épinglage et sauvegarde |
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
| Règles UFW effectives (R10, §1 Réseau) | `Status: active`, `Default: deny (incoming), allow (outgoing), deny (routed)`, une seule règle : `22/tcp ALLOW IN Anywhere` (v4 et v6) |
| SSH effectif (`sshd -T`) | `passwordauthentication no` (fixé par `50-cloud-init.conf`), `pubkeyauthentication yes`, `maxauthtries 6`, écoute `0.0.0.0:22` et `[::]:22`, pas d'`AllowUsers` |
| Sockets non identifiés | `127.0.0.1:39295` cloudflared (métriques), `127.0.0.1:18554` et `*:18555` go2rtc (flux vidéo Home Assistant, réseau hôte, donc bloqué par UFW), `100.121.134.61:63761` tailscaled |
| Swaps actifs (`/proc/swaps`) | `/swapfile` 2 Go (priorité -2, 0 utilisé) et `/dev/zram0` 2 Go ; `/var/swap` n'est pas monté → orphelin |
| Tailles (`du`) | `/var/lib/docker` 8,5 Go, `/var/swap` 1,7 Go, `/swapfile` 2,1 Go |
| Adresse IPv6 globale du Pi (`ip -6 addr show scope global`) | **à faire** : si le Pi porte une adresse IPv6 globale, les ports publiés par Docker (`443:443` sans adresse, donc v4 et v6, et `443:443/udp`) et sshd (`[::]:22`) sont joignables en IPv6 sans passer par la box ; si aucune, le volet IPv6 du test ci-dessous est clos par ce relevé |
| Joignabilité depuis Internet (R10, §1 Réseau) | **à faire** : depuis un réseau extérieur (téléphone en 4G), tester l'IP publique IPv4 de la box **et** l'adresse IPv6 globale du Pi si le relevé précédent en donne une, sur 22, 80, 443, 8096, 1883 et 8123 en TCP, plus **UDP/443** (QUIC publié par Caddy : `curl --http3` ou `nmap -sU -p 443`) ; attendu : tout fermé dans les deux familles. Tant que ce test n'est pas fait, l'audit traite ces ports comme potentiellement exposés |

## 7. Références

- Issue #46 (cette étude) ; issues de report #138, #139, #140, #141, #142 et #26, #29, #131, #90, #130, #22 (voir §5.2) ; #133 (sauvegardes et battements de cœur)
- [ADR 0002 — reverse proxy Caddy](../decisions/0002-caddy-reverse-proxy.md),
  [ADR 0005 — Vaultwarden](../decisions/0005-vaultwarden-deployment.md)
- [bootstrap/harden-ssh.sh](../../bootstrap/harden-ssh.sh),
  [services/n8n/BACKUP.md](../../services/n8n/BACKUP.md)
- CIS Debian Linux Benchmark ; OWASP Docker Security Cheat Sheet
