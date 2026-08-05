# Architecture

This document explains how Home Network Monitor works internally.

---

# High-Level Architecture

```text
                    Internet
                        │
                        ▼
         internet-monitor.sh (Every 5 mins)
                        │
                        ▼
             Internet Status Log
                        │
                        ▼
         speed-monitor.sh (08:00 & 20:00)
                        │
        ┌───────────────┴───────────────┐
        │                               │
        ▼                               ▼
   speed.csv                    state/
        │                               │
        └───────────────┬───────────────┘
                        ▼
          daily-summary.sh (20:05)
                        │
                        ▼
                 Telegram Bot API
                        │
                        ▼
                 Telegram Notification
```

---

# Components

## internet-monitor.sh

Runs every **5 minutes**.

Responsibilities:

- Checks internet connectivity.
- Records whether the connection is UP or DOWN.
- Logs every result.
- Detects connection loss.
- Detects connection recovery.
- Sends outage notifications.

---

## speed-monitor.sh

Runs twice per day.

Schedule:

```text
08:00
20:00
```

Responsibilities:

- Executes speedtest-go.
- Measures:
  - Download speed
  - Latency
- Determines whether the connection is healthy.
- Detects degraded performance.
- Prevents false alerts using consecutive failure detection.
- Records results in CSV format.

---

## daily-summary.sh

Runs once per day.

Schedule:

```text
20:05
```

Responsibilities:

- Reads the latest speed test.
- Calculates today's uptime.
- Creates a human-friendly summary.
- Sends a Telegram notification.

---

## network-monitor

Provides a simple command-line interface.

Available commands:

```bash
network-monitor status

network-monitor check

network-monitor speed

network-monitor test-telegram
```

---

# Configuration

All configuration is stored in:

```text
/opt/home-network-monitor/config.conf
```

The project never stores secrets inside the repository.

Instead, Git tracks:

```text
config/config.example.conf
```

---

# Logs

Internet connectivity:

```text
/opt/home-network-monitor/logs/internet.log
```

Speed tests:

```text
/opt/home-network-monitor/logs/speed.csv
```

These logs provide historical data while remaining lightweight.

---

# State Files

State information is stored in:

```text
/opt/home-network-monitor/state/
```

Examples:

```text
speed.state
speed.failcount
```

These files allow the monitor to remember previous conditions and avoid sending repeated alerts.

---

# Notification Flow

Healthy connection

```text
Internet

↓

Speed Test

↓

Healthy

↓

CSV Log

↓

Daily Summary
```

---

Degraded connection

```text
Internet

↓

Speed Test

↓

Below Threshold

↓

Failure Counter

↓

Threshold Reached

↓

Telegram Alert
```

---

Recovery

```text
Previously Degraded

↓

Healthy Result

↓

State Updated

↓

Telegram Recovery Notification
```

---

# Scheduling

Cron jobs installed by the project:

```text
*/5 * * * * internet-monitor.sh

0 8,20 * * * speed-monitor.sh

5 20 * * * daily-summary.sh
```

---

# Design Goals

The project was designed around a few principles:

- Lightweight
- Minimal dependencies
- Easy to understand
- Easy to deploy
- Easy to maintain
- Human-friendly notifications
- Suitable for long-term homelab use

---

# Future Improvements

Possible future enhancements include:

- Historical trend reporting
- Packet loss monitoring
- Health score
- Multiple notification providers
- Dashboard integration
- Optional web interface

The focus will remain on keeping the project lightweight and easy to maintain.
