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
| Réseau | Accès distant Tailscale uniquement, pas d'ingress public hors tunnel cloudflared de n8n | `tailscale status` : nœud 100.121.134.61 ; aucune redirection box documentée |
| Réseau | UFW actif et activé au démarrage | `systemctl is-active ufw` → `active`, `is-enabled` → `enabled` |
| Hôte | SSH par clé, root interdit, pas de clavier interactif | `PermitRootLogin no`, `KbdInteractiveAuthentication no` ; 0 échec d'authentification en 7 jours |
| Hôte | Mises à jour de sécurité Debian automatiques, sans reboot automatique | `52unattended-upgrades-bb-homelab`, dernier passage 2026-10-23 06:57 |
| Hôte | Horloge synchronisée | `timedatectl` : NTP actif, synchronisé |
| Hôte | Données applicatives hors SD, montage par UUID avec `nofail` | `/mnt/appdata` sur `sda1` (pont USB-SATA JMS578, SMART lisible) |
| Conteneurs | Aucun conteneur privilégié, aucun `docker.sock` monté, aucune capacité ajoutée | `docker inspect` des 10 conteneurs |
| Conteneurs | Healthcheck sur chaque service du dépôt | `docker ps` : 7/7 `healthy` |
| Conteneurs | Services internes derrière Caddy (TLS, CA locale), n8n lié à `127.0.0.1` | Caddyfile : 5 routes `*.bb-homelab.local` ; `127.0.0.1:5678` |
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
| caddy | 2.8.4 | 2.11.7 (2026-10-03) | 3 mineures, 2 ans |
| vaultwarden/server | 1.36.0 | 1.37.4 (2026-10-05) | 1 mineure |
| louislam/uptime-kuma | 2.3.2 | 2.5.7 (2026-10-23) | 2 mineures |
| gethomepage/homepage | v1.13.2 | v2.6.0 (2026-10-17) | **majeure** |
| jellyfin/jellyfin | 10.11.9 | v12.3 (2026-10-23) | **deux majeures** |
| n8nio/n8n | tag `latest` (= 2.16.0, image du 2026-04-07) | 2.44.6 (2026-10-22) | 28 mineures, tag flottant |
| cloudflare/cloudflared | 2024.8.3 | 2026.10.3 (2026-10-21) | 2 ans |
| home-assistant (hors dépôt) | 2026.6.2 | 2026.10.2 | 4 mois |
| zigbee2mqtt (hors dépôt) | 2.12.0 | 2.14.2 | 2 mineures |
| eclipse-mosquitto (hors dépôt) | 2.1.2-alpine | — | à vérifier sur Docker Hub |

## 3. Posture des conteneurs

| Conteneur | Utilisateur | Ports hôte | Durcissement | Données |
|---|---|---|---|---|
| bb-homelab-caddy | root (défaut image) | 80, 443 tcp+udp sur 0.0.0.0 | aucun | `/mnt/appdata/caddy` (PKI de la CA locale, **non sauvegardée**) |
| bb-homelab-vaultwarden | root | aucun (Caddy seul) | aucun | `/mnt/appdata/vaultwarden`, sauvegardé |
| bb-homelab-uptime-kuma | root | aucun | aucun | `/mnt/appdata/uptime-kuma`, **non sauvegardé** |
| bb-homelab-homepage | root (explicite) | aucun | aucun | config versionnée dans le dépôt |
| bb-homelab-jellyfin | root | **8096 sur 0.0.0.0** en plus de la route Caddy | aucun | `/mnt/appdata/jellyfin` |
| bb-homelab-n8n | `node` | 127.0.0.1:5678 | aucun | `/mnt/appdata/n8n`, sauvegardé |
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
| R2 | `cloudflared` 2024.8.3 : seul composant exposé à Internet (tunnel n8n), deux ans de correctifs manquants | 4 | 4 | 16 | **P1** |
| R3 | Carte SD à 94 % (1,7 Go libres) : 13,2 Go d'images Docker sur la SD, 6 Go de `.platformio` hors homelab, deux fichiers swap (`/swapfile` 2 Go, `/var/swap` 1,7 Go) en plus du zram ; un `apt full-upgrade` ou un `docker pull` peut échouer ou corrompre des bases SQLite | 5 | 3 | 15 | **P1** |
| R4 | Caddy 2.8.4 : terminaison TLS et CA locale de tous les services, trois versions mineures de retard | 3 | 4 | 12 | P2 |
| R5 | Vaultwarden 1.36.0 : coffre de mots de passe, une version mineure de retard (1.37.x corrige des problèmes de sécurité côté serveur) | 2 | 5 | 10 | P2 |
| R6 | n8n sur le tag `latest` (`.env` du Pi) : déploiement non reproductible, et 28 versions mineures de retard sur un service qui tient des identifiants d'API | 3 | 3 | 9 | P2 |
| R7 | PKI Caddy (CA locale) et données Uptime Kuma hors sauvegarde : perdre la CA oblige à re-faire confiance sur chaque client ; perdre Kuma efface moniteurs, notifications et historique | 3 | 3 | 9 | P2 |
| R8 | Six conteneurs sur sept tournent root sans `no-new-privileges` ni `cap_drop` : une faille applicative donne root dans le conteneur (recoupe #131) | 2 | 4 | 8 | P2 |
| R9 | Uptime Kuma, Homepage, Jellyfin en retard, dont deux sauts de version majeure (migration à préparer) | 3 | 2 | 6 | P3 |
| R10 | Jellyfin 8096, Home Assistant 8123 et Mosquitto 1883 écoutent sur le LAN en contournant Caddy ; exposition réelle dépendante des règles UFW (§6) | 2 | 3 | 6 | P3 |
| R11 | Aucun scan d'image ni Dependabot sur les images compose (#90, #130) : les retards de §2 ne sont détectés que par un audit manuel | 3 | 2 | 6 | P3 |
| R12 | Trois conteneurs hors dépôt (`~/home-assistant`) : ni épinglage suivi, ni sauvegarde, ni revue | 2 | 2 | 4 | P4 |
| R13 | AppArmor installé mais désactivé au boot ; fail2ban et auditd absents ; `X11Forwarding yes` inutile | 1 | 2 | 2 | P4 |
| R14 | `benoit` membre du groupe `docker` (équivalent root) : accepté, utilisateur unique, clé SSH seule | 1 | 2 | 2 | accepté |

## 5. Feuille de route

### 5.1 Dans la brique #46 (une PR ou une opération par ligne, validée à chaque étape)

| Étape | Risques | Action | Garde-fous |
|---|---|---|---|
| 1 | — | Cet audit (`docs/security/AUDIT.md`) | PR `Refs #46` |
| 2 | R3 | Libérer la SD : supprimer les 4 images inutilisées (n8n 1.97.1, alpine, curl, hello-world : 1,45 Go), `apt clean`, trancher le doublon de swap, décider du sort de `.platformio` | lecture de `/proc/swaps` avant toute suppression ; aucune image utilisée par un conteneur n'est touchée |
| 3 | R4, R5 | Épingler Caddy 2.11.7 et Vaultwarden 1.37.4 (compose + `.env.example`), sauvegarde manuelle avant, `up -d`, QA des cinq routes et connexion au coffre | notes de version lues, retour arrière = ancien tag |
| 4 | R2, R6 | n8n : remplacer `latest` par 2.44.6 dans le `.env` du Pi et le compose ; cloudflared 2026.10.3 | sauvegarde n8n avant, lecture des notes de migration 2.16 → 2.44 |
| 5 | R9 | Uptime Kuma 2.5.7 ; Homepage v2.6.0 et Jellyfin 12.3 après lecture des guides de migration (reportés en issue si le saut majeur exige plus qu'un changement de tag) | sauvegarde Kuma avant (couvre R7 une première fois) |
| 6 | R1 | `sudo apt full-upgrade` lancé par le propriétaire (`ssh -t`), **sans reboot** tant qu'il n'est pas à côté du Pi ; le noyau 6.18 attend ce reboot | `df` avant, SD sous 80 % ; `docker compose ps` après |
| 7 | — | Issues de report (§5.2), fermeture de #46, journal | — |

### 5.2 Reporté en issues (P3/P4)

| Risque | Issue | Décision proposée |
|---|---|---|
| R7 | nouvelle issue « backup : PKI Caddy + données Uptime Kuma » | Étendre le script de sauvegarde et le battement de cœur de #133 |
| R8 | #131 (existante) | Tableau utilisateur / capacités par service, `no-new-privileges` et `cap_drop` là où l'image le supporte |
| R10 | nouvelle issue « réseau : fermer 8096 et revoir l'exposition LAN » | Jellyfin derrière Caddy seul ; décision UFW pour 8123 et 1883 |
| R11 | #90 et #130 (existantes), #22 à fermer | Dependabot compose + Trivy hebdomadaire remplacent Watchtower |
| R1 (récurrence) | nouvelle issue « décision : périmètre d'unattended-upgrades » | Soit ajouter `Debian` stable + dépôts tiers, soit un rappel mensuel ; ADR |
| R12 | nouvelle issue « adopter la pile domotique dans le dépôt » | Déplacer `~/home-assistant` sous `services/` avec épinglage et sauvegarde |
| R13 | nouvelle issue « durcissement hôte : X11Forwarding, AppArmor, fail2ban » | `harden-ssh.sh` désactive X11 ; AppArmor et fail2ban évalués par matrice |

## 6. Relevés en attente (sudo)

À compléter avec la sortie des commandes ci-dessous, lancées par le
propriétaire :

```bash
sudo ufw status verbose
sudo sshd -T | grep -E "^(passwordauthentication|pubkeyauthentication|maxauthtries|allowusers|listenaddress|port) "
sudo cat /etc/ssh/sshd_config.d/50-cloud-init.conf
sudo ss -tulpn | grep -E ":(18555|18554|39295|63761) "
cat /proc/swaps
sudo du -sh /var/lib/docker /var/swap /swapfile
```

| Relevé | Résultat |
|---|---|
| Règles UFW effectives (ports LAN de R10) | à compléter |
| `PasswordAuthentication` effectif | à compléter |
| Processus derrière `*:18555`, `127.0.0.1:18554`, `127.0.0.1:39295` | à compléter |
| Swaps réellement actifs | à compléter |

## 7. Références

- Issue #46 (cette étude), #131, #90, #130, #22, #47, #134
- [ADR 0002 — reverse proxy Caddy](../decisions/0002-caddy-reverse-proxy.md),
  [ADR 0005 — Vaultwarden](../decisions/0005-vaultwarden-deployment.md)
- [bootstrap/harden-ssh.sh](../../bootstrap/harden-ssh.sh),
  [services/n8n/BACKUP.md](../../services/n8n/BACKUP.md)
- CIS Debian Linux Benchmark ; OWASP Docker Security Cheat Sheet
