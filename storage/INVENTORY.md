# storage/INVENTORY.md — Registre des disques

Registre de tous les disques (HDD, SSD, NVMe) physiquement intégrés au
homelab, avec leur baseline SMART au moment de l'intégration et leur
rôle dans le Pattern Y.

## Pattern Y (rappel)

Le projet utilise un schéma à trois disques tiered (décision 2026-04-15) :

- **Disque A** — `appdata` + `archive` : accès quotidien, performance
  prioritaire (n8n volumes, futur Postgres ; documents administratifs,
  photos, vidéos perso).
- **Disque B** — `media` : Jellyfin, gros volume séquentiel.
- **Disque C** — `backup` : snapshots restic, dumps SQLite n8n,
  exports Postgres.

Chaque disque doit obligatoirement être enregistré ici **avant** de
recevoir des données utilisateur, et son SMART baseline (health overall +
attributs critiques + short self-test) doit être capturé pour détection
de dérive ultérieure.

## Convention d'identification

- **ID** : numéro séquentiel `#1`, `#2`, … attribué à la première
  intégration du disque. Jamais réutilisé même si retiré.
- **Rôle** : `disk-a` / `disk-b` / `disk-c` / `spare` / `retired`.
- **État** : `active` / `spare` / `retired` / `failing`.

## Disques actifs

### Disk #7 — Seagate Barracuda 2.5 5400 (rôle `disk-a`)

| Champ | Valeur |
|---|---|
| Modèle | Seagate Barracuda 2.5 5400 (`ST500LM030-2E717D`) |
| Capacité | 500 GB (500 107 862 016 bytes) |
| Form factor | 2.5" |
| Numéro de série | `ZDEJ9BW5` |
| WWN | `5 000c50 0c4c7085c` |
| Firmware | `0001` |
| Interface | SATA 3.1, 6.0 Gb/s (négocié à 6 Gb/s) |
| Sectors | 512 logiques / 4096 physiques (Advanced Format) |
| Vitesse rotation | 5400 rpm |
| Date d'acquisition | 2026-05-08 (récupéré recyclé) |
| **Enclosure USB-SATA** | JMicron **JMS578** (`152d:0578`, SMART passthrough OK) |
| **Date d'intégration** | 2026-05-08 |
| **Mount point** | `/mnt/appdata` |
| **Filesystem UUID** | `aed8879a-543a-4d43-90b1-0fb05aa371ea` |
| **PARTUUID** | `b5a1c48a-f906-48bb-8127-d58b6118b2d6` |
| **Filesystem** | ext4 v1.0, label `bb-appdata` |
| **Table de partition** | GPT, 1 partition primaire couvrant tout le disque |
| **Options fstab** | `defaults,nofail`, dump=0, fsck pass=2 |

#### Baseline SMART (2026-05-08 16:01 CEST)

- Health overall : `PASSED`
- Power_On_Hours : 2 (disque pratiquement neuf)
- Power_Cycle_Count : 3
- Reallocated_Sector_Ct / Current_Pending_Sector / Offline_Uncorrectable : 0 / 0 / 0
- End-to-End_Error / UDMA_CRC_Error_Count / Reported_Uncorrect : 0 / 0 / 0
- Free_Fall_Sensor : 0 ; G-Sense_Error_Rate : 1 (transport mineur)
- Temperature_Celsius : 24°C (Min/Max 24/24)
- Total_LBAs_Written : ~32 GB (cohérent avec un disque très peu utilisé)

#### Short self-test (2026-05-08 16:11 CEST)

- Status : `Completed without error`
- LifeTime à l'exécution : 2 heures
- LBA_of_first_error : aucun

#### Notes

- Disque récupéré recyclé. Contenait avant intégration une installation
  Windows 10 IoT en MBR legacy + une partition `Data` 302 GB NTFS. Wipé
  via `wipefs -a` le 2026-05-08.
- Pattern Y : prend le rôle `disk-a` (`appdata` + `archive`) initialement
  réservé au WD Black 500 GB de l'inventaire d'origine (en attente
  d'enclosure compatible, issue #47). Arbitrage des rôles à revoir
  quand le WD Black sera intégrable.
- Phase 1 d'intégration (2026-05-08) : seul `/mnt/appdata` est monté.
  Le rôle `archive` (`/mnt/archive`) est différé (Option γ — 1 partition
  unique, mount direct, pas de bind-mount pour archive en attendant
  d'autres disques).
- Tests post-intégration : `mount -a` sans erreur, lecture + écriture +
  suppression d'un fichier test confirmées. Reboot test non encore
  effectué — à valider lors du prochain reboot planifié.

## Disques en attente d'intégration

Ces disques sont identifiés (Pattern Y du 2026-04-15) mais bloqués sur
réception d'enclosures USB-SATA compatibles (issue #47).

- **WD Black WD5000LPLX 500 GB (2018)** — rôle prévu `disk-a` (à
  réarbitrer post-arrivée).
- **Seagate BarraCuda ST1000LM048 1 TB (2018)** — rôle prévu `disk-b`.
- **WD Blue WD10JPCX 1 TB (2016)** — rôle prévu `disk-c`.
- **HGST Z5K500 500 GB (2013)** — réserve / disque de test.

## Disques écartés

- Hitachi IC25N060 60 GB IDE (2007) — interface PATA incompatible.
- Samsung HM121HC 120 GB (2007) — trop ancien.

## Procédure d'intégration condensée

(Version détaillée à venir dans `storage/MOUNT.md`, issue #10.)

1. Vérifier le chipset USB-SATA via `lsusb` (rejeter JMS583).
2. Capturer la baseline SMART (`smartctl -i -H -A` + `-t short`).
3. Wiper toute partition existante (`wipefs -a /dev/sdX`).
4. Créer table GPT + 1 partition couvrant le disque (`parted`).
5. Formater ext4 avec un label explicite (`mkfs.ext4 -L bb-<role>`).
6. Ajouter ligne `/etc/fstab` : UUID + `nofail`.
7. Tester via `mount -a` (sans reboot).
8. Tester l'écriture (touch + cat + rm).
9. Enregistrer le disque ici.
10. Reboot test à la prochaine fenêtre planifiée.
