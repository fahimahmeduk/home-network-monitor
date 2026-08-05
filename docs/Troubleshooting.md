# Troubleshooting

This guide covers common issues that may occur when installing or running Home Network Monitor.

---

# Telegram messages are not being delivered

## Symptoms

- No Telegram notifications
- `network-monitor test-telegram` produces no message

## Checks

Verify your configuration:

```bash
cat /opt/home-network-monitor/config.conf
```

Ensure:

```text
BOT_TOKEN="..."
CHAT_ID="..."
```

Verify your bot token:

```bash
curl https://api.telegram.org/botYOUR_TOKEN/getMe
```

Expected:

```json
"ok": true
```

If the response is:

```text
404 Not Found
```

your Bot Token is incorrect.

---

# Test Telegram manually

Run:

```bash
network-monitor test-telegram
```

If no message is received, confirm:

- Bot Token
- Chat ID
- Internet connectivity

---

# speedtest-go not found

## Symptoms

```text
speedtest-go: command not found
```

Verify:

```bash
which speedtest-go
```

Expected:

```text
/usr/local/bin/speedtest-go
```

If it is missing, reinstall it following:

```
docs/Installation.md
```

---

# jq missing

## Symptoms

```text
jq: command not found
```

Install:

```bash
sudo apt update
sudo apt install jq
```

Verify:

```bash
jq --version
```

---

# Cron jobs are missing

View cron jobs:

```bash
crontab -l
```

Expected:

```text
*/5 * * * * internet-monitor.sh

0 8,20 * * * speed-monitor.sh

5 20 * * * daily-summary.sh
```

If they are missing, run:

```bash
./install.sh
```

---

# Scripts fail syntax check

Check a script:

```bash
bash -n scripts/speed-monitor.sh
```

No output means the syntax is valid.

---

# Configuration file missing

Check:

```bash
ls -l /opt/home-network-monitor/config.conf
```

If missing:

Run:

```bash
./install.sh
```

The installer creates a configuration file automatically if one does not already exist.

---

# Permission denied

If a script cannot execute:

```bash
chmod +x script-name.sh
```

Example:

```bash
chmod +x scripts/speed-monitor.sh
```

---

# Daily Summary not received

Run manually:

```bash
/opt/home-network-monitor/daily-summary.sh
```

If it works manually but not automatically:

Check cron:

```bash
crontab -l
```

---

# Speed tests always fail

Verify manually:

```bash
speedtest-go
```

If this fails:

- Check internet connectivity
- Verify the configured server ID
- Try another server:

```bash
speedtest-go --list
```

Update:

```text
SPEEDTEST_SERVER_ID=
```

inside:

```text
/opt/home-network-monitor/config.conf
```

---

# Verify Installation

Run:

```bash
network-monitor status
```

Expected output:

- Internet state
- Last connectivity check
- Last speed test

---

# Collect Useful Information

Before reporting an issue, collect:

Current status:

```bash
network-monitor status
```

Cron jobs:

```bash
crontab -l
```

Configuration:

```bash
cat /opt/home-network-monitor/config.conf
```

**Remove your Bot Token before sharing.**

Version:

```bash
git log --oneline -5
```

---

# Still Having Problems?

1. Verify the installation guide.
2. Review the configuration.
3. Run the scripts manually.
4. Check the logs.
5. Confirm all required dependencies are installed.

Most issues can be resolved by following these steps.
