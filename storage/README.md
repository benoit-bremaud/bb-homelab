# storage/ — Layer 1 (Storage)

Everything related to where data lives: external HDD mounts, SMART
health checks, backup scripts (local + off-site), and the conventions
that keep media libraries auto-detectable by Jellyfin.

## What lives here (planned)

| Topic | File | Tracked in |
|---|---|---|
| `/mnt` layout convention (Pattern Y, roles) | `LAYOUT.md` | issue #49 |
| External HDD mounting (fstab, by-uuid) | `MOUNT.md` | issue #10 |
| SMART health monitoring script | `scripts/smart-check.sh` | issue #11 |
| Media folder structure conventions | `MEDIA.md` | issue #13 |
| Nightly backup script | `scripts/nightly-backup.sh` | issue #18 |
| Off-site restic backup | `RESTIC.md` | issue #19 |
| Disk redundancy decision | (ADR) | decision #27 |

## Hardware inventory

Filled in once disks are plugged into the Pi and identified:

| Device | UUID | Capacity | Health (smartctl) | Mount point | Role |
|---|---|---|---|---|---|
| _(pending)_ | | | | | |

## 3-2-1 backup principle

The strategy this folder implements:

- **3** copies of any important data
- **2** different physical media (e.g. SSD + HDD, or RPi + cloud)
- **1** off-site copy (cloud or another physical location)

Local nightly backups handle the first two; off-site (restic to
Backblaze B2 or similar) handles the third.
