# Home Network Monitor

A lightweight Bash-based home network monitoring utility built for my Ubuntu CasaOS homelab.

The project monitors internet connectivity, performs scheduled speed tests, logs network performance, and sends Telegram alerts when issues are detected.

---

## Features

- 🌐 Internet connectivity monitoring
- 📉 Speed degradation detection
- 📱 Telegram notifications
- 📄 CSV logging
- ⚡ Lightweight (zero idle RAM usage)
- 🛠️ Simple CLI utility
- 🔧 Easy configuration

---

## Requirements

- Ubuntu
- Bash
- curl
- jq
- speedtest-go
- cron

---

## Commands

```bash
network-monitor status
network-monitor check
network-monitor speed
network-monitor logs
network-monitor test-telegram
```

---

## Folder Structure

```
config/
docs/
scripts/
assets/
```

---

## Current Version

v1.0.0

---

## Roadmap

### v1.0

- Internet monitoring
- Telegram notifications
- Speed monitoring

### v1.1

- Installer
- Uninstaller
- Better CLI

### v1.2

- Dashboard
- Statistics
- Weekly Reports

### v2.0

- Docker Edition
- Web Dashboard
- REST API

---

## License

MIT
