# bb-homelab

Self-hosted services running on a Raspberry Pi 5 at home: automation
(n8n), media center (Jellyfin), personal projects (brasse-bouillon), and
the small ecosystem of tools that surrounds them (reverse proxy,
backups, monitoring).

The repo is **hardware-agnostic by design**: today it runs on a Pi, tomorrow
it could run on a mini-PC or a VPS without rewriting any service.

## Quick links

| Layer | Where |
|---|---|
| Architecture & design decisions | [ARCHITECTURE.md](ARCHITECTURE.md), [docs/decisions/](docs/decisions/) |
| First-time host setup (OS, Docker, SSH) | [bootstrap/](bootstrap/) |
| Network & remote access (Tailscale, reverse proxy) | [network/](network/) |
| Services (one folder per docker-compose stack) | [services/](services/) |
| Storage (HDD mounts, SMART checks, backups) | [storage/](storage/) |
| Operational logbook | [PROJECT_LOG.md](PROJECT_LOG.md) |
| Contribution conventions | [CONTRIBUTING.md](CONTRIBUTING.md) |

## What's deployed today

Tracked in [PROJECT_LOG.md](PROJECT_LOG.md). The full backlog lives in
[GitHub Issues](https://github.com/benoit-bremaud/bb-homelab/issues) and on
the project board.

## Getting started on a fresh Pi

The end state we're aiming for: any spare RPi (or fresh SD card) should be
installable from zero to "ready to run services" in a single bootstrap
script. Until that issue lands, follow the manual steps in
[bootstrap/README.md](bootstrap/README.md).

## License

Documentation and configuration in this repository are released under
[CC BY-SA 4.0](LICENSE). Code snippets (shell scripts, Compose files) are
short and follow the same license unless noted otherwise.
