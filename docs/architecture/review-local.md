# Local review — bb-homelab (fix/139-bind-ports-tailnet-loopback)

- Date: 2026-11-02
- Commit: 6490a2e
- Scope: branch diff origin/main...HEAD
- Checks run: containers · security · correctness · docs (no application code, no tests in scope)
- Verdict: ship as-is · Must 0 · Should 0 open (4 fixed) · Nice 2

## Pre-merge gate (head SHA 6490a2e)

| Step | Result |
|---|---|
| 1 Tests | n/a: no application code; shellcheck, yamllint, `docker compose config` pass |
| 2 Coverage | n/a (project deviation: linters and config validation replace coverage) |
| 3 SonarQube | ✅ PASSED |
| 4 Secrets | ✅ gitleaks clean (origin/main..HEAD) · no tracked .env · diff read: only the tailnet IP, already public |
| 5 QA pass | pending: applied on the Pi with the owner, then probed from LAN and tailnet |

- Gate: **GREEN for push**; merge waits for step 5.

## 🔴 Must Have

_None._

## 🟡 Should Have

- Fixed in 6490a2e: stale "tailnet/LAN" claims in `services/jellyfin/README.md`; `sysctl -p` no
  longer aborts `bootstrap.sh`; ADR 0007 states IP-change recovery, host-wide sysctl scope and the
  deploy order.

## 🔵 Nice to Have

- `network/README.md`: add a UDP/443 probe from the LAN to the check command.
- `bootstrap/README.md`: add the sysctl value to post-install checks (already shown by `cat`).

## ⚪ Disagree / Intentional

- `services/caddy/docker-compose.yml`, `services/jellyfin/docker-compose.yml` · tailnet IP hardcoded
  instead of `TAILNET_IP` in `.env` · owner decision 2026-11-02 (stable IP, already public, YAGNI).

## Per-dimension summary

- Containers: no internal caller depends on LAN/bridge paths · Security: LAN exposure removed, IPv6
  dropped · Correctness: boot race covered by the sysctl · Docs: language categories respected.
