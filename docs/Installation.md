# Installation Guide

This guide walks through installing **Home Network Monitor** on Ubuntu.

---

# Supported Operating Systems

The project has been tested on:

- Ubuntu Server 24.04 LTS

Other Debian-based distributions may also work but are currently untested.

---

# Requirements

Before installing, ensure the following packages are available:

- Bash
- curl
- jq
- cron
- ping
- awk
- timeout (coreutils)

Verify the required commands:

```bash
command -v curl jq awk ping timeout
```

---

# Install speedtest-go

This project uses **speedtest-go** for scheduled internet speed tests.

Download the latest release:

```bash
DOWNLOAD_URL=$(curl -s https://api.github.com/repos/showwin/speedtest-go/releases/latest \
| grep browser_download_url \
| grep Linux_x86_64 \
| cut -d '"' -f4)
```

Download:

```bash
cd /tmp
curl -L "$DOWNLOAD_URL" -o speedtest-go.tar.gz
```

Extract:

```bash
tar -xzf speedtest-go.tar.gz
```

Install:

```bash
sudo install -m 0755 speedtest-go /usr/local/bin/speedtest-go
```

Verify:

```bash
speedtest-go --version
```

---

# Clone the Repository

```bash
git clone git@github.com:fahimahmeduk/home-network-monitor.git

cd home-network-monitor
```

---

# Install

Run:

```bash
./install.sh
```

The installer will:

- Create the installation directory
- Install all scripts
- Install the CLI
- Create the configuration file (if required)
- Configure scheduled cron jobs

---

# Configure Telegram

Edit:

```bash
sudo nano /opt/home-network-monitor/config.conf
```

Update:

```text
BOT_TOKEN=
CHAT_ID=
```

---

# Verify Installation

Check the CLI:

```bash
network-monitor status
```

Run a Telegram test:

```bash
network-monitor test-telegram
```

Run a manual connectivity check:

```bash
network-monitor check
```

Run a manual speed test:

```bash
network-monitor speed
```

---

# Verify Scheduled Tasks

View the installed cron jobs:

```bash
crontab -l
```

Expected output:

```text
*/5 * * * * /opt/home-network-monitor/internet-monitor.sh >/dev/null 2>&1

0 8,20 * * * /opt/home-network-monitor/speed-monitor.sh >/dev/null 2>&1

5 20 * * * /opt/home-network-monitor/daily-summary.sh >/dev/null 2>&1
```

---

# Updating

Pull the latest changes:

```bash
git pull
```

Reinstall:

```bash
./install.sh
```

---

# Uninstall

Run:

```bash
./uninstall.sh
```

The uninstaller allows you to:

- Remove scripts only
- Preserve configuration
- Preserve logs
- Preserve historical monitoring data

---

# Troubleshooting

If installation fails, see:

```
docs/Troubleshooting.md
```
