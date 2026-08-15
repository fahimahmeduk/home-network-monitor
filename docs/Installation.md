# Installation

## Supported environment

Home Network Monitor is designed for a Linux server running Bash and cron. Ubuntu Server is the primary tested platform.

## Prerequisites

Confirm these commands are available:

```bash
command -v curl
command -v jq
command -v ping
command -v timeout
command -v crontab
command -v flock
command -v speedtest-go
```

Install [`speedtest-go`](https://github.com/showwin/speedtest-go) from its official release instructions and ensure the binary is executable.

## Install from GitHub

```bash
git clone https://github.com/fahimahmeduk/home-network-monitor.git
cd home-network-monitor
./install.sh
```

The installer:

- Checks dependencies
- Installs scripts under `/opt/home-network-monitor`
- Installs the CLI under `/usr/local/bin/network-monitor`
- Creates a private configuration file
- Creates writable log and state directories
- Adds idempotent cron entries for the current user
- Preserves configuration during upgrades

## Configure Telegram and thresholds

```bash
sudo nano /opt/home-network-monitor/config.conf
```

At minimum, replace:

```bash
BOT_TOKEN="YOUR_TELEGRAM_BOT_TOKEN"
CHAT_ID="YOUR_TELEGRAM_CHAT_ID"
```

Review the speed thresholds and server IDs. See [Configuration](Configuration.md).

## Validate

```bash
network-monitor test-telegram
network-monitor check
network-monitor status
```

Run one manual speed test:

```bash
time network-monitor speed
network-monitor status
```

A speed test can use 1–2 GB. If confirmation is required, two tests may run.

Send a daily summary manually:

```bash
network-monitor summary
```

## Verify cron

```bash
crontab -l | grep HOME-NETWORK-MONITOR
```

Expected entries:

```text
*/5 * * * * /opt/home-network-monitor/internet-monitor.sh >/dev/null 2>&1 # HOME-NETWORK-MONITOR
0 8,20 * * * /opt/home-network-monitor/speed-monitor.sh >/dev/null 2>&1 # HOME-NETWORK-MONITOR
10 20 * * * /opt/home-network-monitor/daily-summary.sh >/dev/null 2>&1 # HOME-NETWORK-MONITOR
```

## Upgrade

From the repository:

```bash
git pull --ff-only
./install.sh
```

The installer preserves the live `config.conf` and adds missing settings. The first speed test after a CSV schema change archives the previous log.

Always review release notes before upgrading.

## Uninstall

From the repository:

```bash
./uninstall.sh
```

Review the uninstaller output carefully, particularly if runtime logs or configuration should be retained.
