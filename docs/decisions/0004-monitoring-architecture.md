# ADR 0004 — Monitoring architecture: layered active + passive, single fault-only alert channel

- **Status**: Accepted
- **Date**: 2026-05-23

## Context

bb-homelab is growing into a multi-service homelab. "Is everything
up?" can no longer be answered by manually opening a dashboard. We need
to be *notified* when something breaks — and only then.

An audit of the existing setup revealed a fragmented, partly broken
monitoring landscape:

- **Uptime Kuma** was just deployed on the Pi (issue #44) but had no
  notification channel wired.
- A **`wan-monitor`** ran on the *laptop* as a systemd user timer,
  pinging Healthchecks.io as a dead-man's-switch for the home WAN.
  Because the laptop sleeps and shuts down nightly, the timer froze
  whenever the laptop was asleep — Healthchecks.io recorded those gaps
  as outages. The "72.7% uptime / 54 outages" it reported was measuring
  *laptop-on-ness*, not the WAN. The signal was misleading.
- An **`n8n-watchdog`** ran on the laptop, watching the laptop's local
  n8n container, alerting through a Telegram bot shared with the Kaggle
  project (`@kaggle_watcher_bb_bot`).

Three real needs were identified:

- **N1 — Pi down**: the Pi itself dies (power cut, network loss, crash).
- **N2 — service on the Pi down**: n8n or Caddy is down while the Pi is
  otherwise healthy.
- **N3 — home WAN down**: the house loses internet (5G / fibre).

The decisive constraint is the **"who watches the watcher?"** problem: a
monitor co-located with (or running on) the host it watches cannot
report that host's own death. If the dead-man's-switch lived on the Pi,
a Pi power-cut or WAN loss would kill the watcher too — it could never
send the alert. Detecting N1 (power) and N3 (WAN) therefore *requires*
an observer that is off-site and on its own internet connection.

There are two complementary monitoring paradigms, serving different
needs:

- **Active probing** (Uptime Kuma): the monitor reaches out to a
  service (HTTP/TCP/ping) and checks it responds. Good for N2.
- **Passive dead-man's-switch** (Healthchecks.io): the monitored host
  pings the monitor on a schedule; a missing ping triggers an alert.
  Good for N1/N3 *only* when the monitor is external.

## Decision

Adopt a **layered monitoring architecture** — three layers, one alert
channel, fault-only — mapping each need to the paradigm that can
actually satisfy it.

1. **Active internal probing — Uptime Kuma on the Pi (N2).** HTTP/TCP
   probes of the Pi's own services (n8n `/healthz`, Caddy on TCP 443).
   Gives a dashboard and fine-grained per-service status. Routed
   internally via `status.bb-homelab.local` (ADR 0002).

2. **External dead-man's-switch — SaaS Healthchecks.io (N1 power +
   N3 WAN).** The Pi pings Healthchecks.io on a schedule; if the pings
   stop — for *any* reason (Pi dead, power cut, WAN down) — Healthchecks
   .io alerts from off-site over its own connection. **Self-hosting
   Healthchecks is rejected** here: on the Pi it hits the watcher
   paradox; on the LAN it cannot detect a WAN outage.

3. **On-premise cross-watch — second Pi (Pi 3), planned.** A second,
   independent Pi actively watches the Pi 5 for *isolated* failures
   (crash, SD corruption, hung service) and vice-versa. It *complements*
   but does **not replace** layer 2: both Pis share the same site and
   mains power, so a power cut is a common-cause failure that only the
   off-site switch can surface. This layer is deferred (the Pi 3 needs
   bootstrapping) and is a robustness/learning enhancement, not on the
   critical path for N1–N3.

Cross-cutting decisions:

- **Single alert channel: one dedicated Telegram bot**
  (`@bb-infra-alerts`, working name), separate from the Kaggle project
  bot. Domain isolation — infra alerts must not be coupled to an
  application bot, and the bot must be revocable independently. All
  layers route to this one bot (same destination chat as today).
- **Fault-only — "no news is good news".** No "all good" / recovery /
  heartbeat notifications. Healthchecks.io is wired via its **webhook**
  integration on the *down* transition only (its native Telegram
  integration uses Healthchecks.io's own bot and would also send
  recoveries). Uptime Kuma notifies on DOWN; whether its recovery
  message can be suppressed is to be confirmed in the UI (worst case:
  one recovery message per real incident — not spam).
- **Decommission the laptop watchers.** The laptop `wan-monitor` and
  `n8n-watchdog` are retired: the laptop's sleep/shutdown cycle makes
  its signal misleading, and the needs they approximated are relocated
  to the always-on Pi. The laptop's local n8n (Kaggle stack) is no
  longer a monitoring target (need dropped during the design review).

## Consequences

**Positive:**

- Each need is covered by the paradigm that can actually satisfy it;
  no more false outages from laptop sleep.
- One notification channel, fault-only — low-noise, high-signal.
- Free: Healthchecks.io free tier + self-hosted Uptime Kuma.
- The off-site layer survives Pi, WAN, and power loss — the failures
  that matter most go out over an independent connection.

**Negative:**

- The off-site layer depends on a third-party SaaS (Healthchecks.io).
  Data sent is minimal (a ping, the check name) plus the bot token
  stored in the webhook integration config — no service content, no
  PII. Acceptable for a homelab; revisit if data sensitivity changes.
- The planned Pi 3 cross-watch is extra hardware to bootstrap and
  maintain, and — being on the same mains as the Pi 5 — cannot cover a
  power cut on its own (mitigated by layer 2).
- Uptime Kuma's recovery message may not be fully suppressible; "fault-
  only" is best-effort on that layer.

## Alternatives considered

- **Self-host Healthchecks.io (on the Pi or the LAN).** Rejected: the
  watcher paradox — it cannot report the death of its own host, and on
  the LAN it cannot detect a WAN outage. Defeats N1/N3, the very needs
  it would exist for.
- **Uptime Kuma only.** Rejected: it runs on the Pi, so it is blind to
  whole-Pi / power / WAN failure — it dies with the thing it watches.
- **All-passive (drop Uptime Kuma; everything as Pi scripts pinging
  Healthchecks.io).** Considered and viable, but Uptime Kuma is kept
  for its active dashboard and low-effort per-service probing UX.
- **Reuse `@kaggle_watcher_bb_bot` or Healthchecks.io's native Telegram
  bot.** Rejected for domain isolation: infra alerting should not be
  coupled to an application project's bot, and a dedicated bot can be
  rotated/revoked without collateral.
- **Keep the laptop-based watchers.** Rejected: laptop sleep produces
  false outages (the misleading 72.7% figure), and a dead-man's-switch
  only means something on an always-on host.

## Refs

- Issue #44 — deploy monitoring Stack B (Uptime Kuma, part 1)
- ADR 0002 — Caddy reverse proxy (Kuma routed via
  `status.bb-homelab.local`)
- `services/uptime-kuma/` — implementation (compose, README)
- `home-infra-watchdog` repo — `wan-monitor` (to be relocated to the
  Pi), `radio-mode-monitor` (skeleton, future)
- UML: `docs/architecture/diagrams/monitoring/` (component, data-flow)
- Note: ADR number 0003 is reserved for the pending Jellyfin media
  server decision (listed in the index, not yet written).
