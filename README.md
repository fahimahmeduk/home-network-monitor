# 🏠 Home Network Monitor

A lightweight Bash-based home network monitoring solution for Ubuntu that monitors internet connectivity, scheduled speed tests, and sends intelligent Telegram notifications.

This project was built as part of my personal homelab to give me visibility into the health of my home internet connection without relying on heavy monitoring platforms.

---

## ✨ Features

- 🌐 Internet connectivity monitoring every 5 minutes
- ⚡ Automated speed tests using speedtest-go
- 📊 Daily Telegram network summary
- 🟢 Performance health monitoring
- 🟠 Intelligent degradation detection (consecutive failures)
- ✅ Automatic recovery notifications
- 📝 CSV logging for historical results
- ⚙️ Configurable thresholds
- 🔧 Simple installer and uninstaller
- 🐧 Lightweight Bash implementation with minimal dependencies

---

# Why I Built This

Like many people with a homelab, I wanted to know:

- Is my internet connection actually stable?
- Has my download speed dropped?
- Is latency increasing?
- Did my internet briefly disconnect while I was away?
- Can I receive simple notifications without running a large monitoring stack?

Rather than deploying another dashboard or heavy monitoring platform, I built a lightweight solution that integrates directly with Telegram.

The goal was to create something reliable, easy to maintain, and suitable for long-term use on my Ubuntu homelab.

---

# Architecture

```text
Internet
     │
     ▼
internet-monitor.sh
     │
     ▼
speed-monitor.sh
     │
     ▼
CSV Logs
State Files
     │
     ▼
daily-summary.sh
     │
     ▼
Telegram
```

---

# Project Structure

```text
home-network-monitor
│
├── config
├── docs
├── scripts
├── assets
│
├── README.md
├── CHANGELOG.md
├── LICENSE
├── install.sh
└── uninstall.sh
```

---

# Screenshots

The following screenshots demonstrate the project in action.

- Telegram Daily Summary
- CLI Status
- GitHub Repository
- Architecture Diagram
- Cron Schedule

*(Screenshots will be added in the next release.)*

---

# Installation

Clone the repository:

```bash
git clone git@github.com:fahimahmeduk/home-network-monitor.git
cd home-network-monitor
```

Run the installer:

```bash
./install.sh
```

Configure your Telegram bot:

```bash
sudo nano /opt/home-network-monitor/config.conf
```

Detailed installation instructions are available in:

```
docs/Installation.md
```

---

# Commands

View current status

```bash
network-monitor status
```

Run an internet check

```bash
network-monitor check
```

Run a manual speed test

```bash
network-monitor speed
```

Send a Telegram test message

```bash
network-monitor test-telegram
```

---

# Documentation

Additional documentation is available in the **docs** directory.

- Architecture
- Installation
- Configuration
- Telegram Notifications
- Troubleshooting
- Roadmap

---

# Technologies Used

- Bash
- Ubuntu
- Cron
- speedtest-go
- jq
- curl
- Telegram Bot API
- Git
- GitHub

---

# Roadmap

## ✅ v1.2.0

- Intelligent speed monitoring
- Telegram notifications
- Daily network summary
- Recovery notifications
- Installer / Uninstaller
- Configuration management
- CSV logging

## 🚀 Planned

- Health score
- Packet loss reporting
- ISP statistics
- Historical reporting
- Additional notification providers

---

# License

This project is licensed under the MIT License.

---

# Author

**Fahim Ahmed**

GitHub:

https://github.com/fahimahmeduk

---

⭐ If you found this project useful, consider giving it a star.
