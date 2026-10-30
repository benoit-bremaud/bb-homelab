# Local review — bb-homelab (branch diff main...fix/168-disable-uas-jms578)

- Date: 2026-10-30
- Commit: a809f1f (gitleaks re-run on 0d58aa8, which adds the PROJECT_LOG entry; the next commit only updates this report)
- Scope: branch diff `main...HEAD` (`storage/INVENTORY.md`) plus the
  host change on the Pi (`/boot/firmware/cmdline.txt`, not versioned)
- Checks run: docs · security · correctness (design, tests, containers:
  N/A, docs-only diff)
- Verdict: ship · Must 2 (all fixed) · Should 2 (all fixed) · Nice 2
  (kept, see below)

## Pre-merge gate (head SHA a809f1f)

| Step | Result |
|---|---|
| 1 Tests | N/A: docs only · markdownlint clean (only the known MD060 false positive) |
| 2 Coverage | N/A (no code) |
| 3 SonarQube | ✅ PASSED |
| 4 Secrets | ✅ gitleaks clean (`--log-opts=--all`) · no tracked .env · diff read: no IP, MAC, city or serial added |
| 5 QA pass | ✅ smoke on the Pi after the reboot: `lsusb -t` shows `Driver=usb-storage`, kernel logs "UAS is ignored for this device", `/mnt/appdata` mounted from `sda1`, every container with a healthcheck healthy (Home Assistant included), Zigbee2MQTT started, tunnel registered |

Waiver: no GitHub Actions credit (#21); the gate runs locally.

- Gate: **GREEN — merge authorised** after the owner's approval

## 🔴 Must Have

- `storage/INVENTORY.md:111` `[docs]` · "reboot test not done yet"
  contradicted the new note · **fixed** in a809f1f
- `storage/INVENTORY.md:113` `[docs]` · the post-reboot check read as a
  procedure, not a result · **fixed** in a809f1f (dated result)

## 🟡 Should Have

- `storage/INVENTORY.md:93,113` `[docs]` · UAS stated as the proven
  cause · **fixed**: worded as the probable cause
- `storage/INVENTORY.md:117` `[docs]` · rollback without the backup
  path · **fixed**: full `cp` command

## 🔵 Nice to Have

- `storage/INVENTORY.md:90` `[docs]` · "aggressive head parking" is an
  unsourced reading · kept: it mirrors the issue's SMART analysis
- `storage/INVENTORY.md:52,143` `[docs]` · the quirk string appears
  three times · kept: each place serves a different reader (disk
  sheet, note, integration procedure)

## ⚪ Disagree / Intentional

_None._

## Per-dimension summary

- Design: N/A · Docs: 4 fixes applied · Tests: N/A · Security: nothing
  sensitive added; the pre-existing serial number on the disk sheet is
  out of scope · Correctness: SMART figures match the issue comment
