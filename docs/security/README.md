# Security — bb-homelab host and network

How the Raspberry Pi 5 host and its network are tested for security: the pentest plan, its
rules of engagement and the dated reports.

## Scope split

The hub services run on this Pi but are tested from their own repository (owner MCDA,
2026-11-03, home-assistant#95). Test IDs are shared across both plans, so a test keeps one ID.

| Target | Repository | Plan |
|---|---|---|
| Host and network: internet exposure, n8n tunnel, tailnet, OS, Docker daemon, SSH, LAN announcements, SD card | this repository | [pentest-plan.md](pentest-plan.md) |
| Hub services: Mosquitto, Home Assistant, go2rtc, Zigbee2MQTT, Zigbee gateway, ESPHome nodes, curing-chamber resilience | `home-assistant` | [home-assistant `docs/security/`](https://github.com/benoit-bremaud/home-assistant/tree/main/docs/security) |

The 2026-10-23 configuration audit, its risk register and roadmap stay in
[AUDIT.md](AUDIT.md).

## Rules of engagement

- **Production only.** The Pi has no other tier: every test runs against the live services.
- **Owner's go per test** in chat before any active test (risk *Low* or above). *None* tests
  (read-only) run without asking.
- **High-risk tests** (DoS, firewall changes, reboot) run in a maintenance window agreed with
  the owner, with the rollback written down first; the owner is near the Pi for anything that
  may drop SSH.
- **No secret in a report**: redact tokens, passwords, keys, tunnel credentials; public IPs,
  tunnel URLs and tailnet addresses stay out of the repository.
- **One issue per finding** (duplicate search first), on GitHub Project #48 `bb-homelab` or
  Project #77 `home-assistant`; the plan's status column links it.
- Each session writes a dated report under [reports/](reports/) (`YYYY-MM-DD-topic.md`).

## Reports

| Date | Report |
|---|---|
| 2026-11-03 | [Pentest session 1 — host and network](reports/2026-11-03-pentest.md) |
| 2026-10-23 | [Configuration audit](AUDIT.md) |
