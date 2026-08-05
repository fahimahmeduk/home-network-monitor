# Configuration Guide

Home Network Monitor is configured using a single configuration file.

Default location:

```text
/opt/home-network-monitor/config.conf
```

---

# Example Configuration

```bash
BOT_TOKEN="YOUR_TELEGRAM_BOT_TOKEN"
CHAT_ID="YOUR_TELEGRAM_CHAT_ID"

DOWNLOAD_THRESHOLD_MBPS="600"
LATENCY_THRESHOLD_MS="30"
SPEEDTEST_SERVER_ID="30690"

NOTIFY_ON_SUCCESS="false"
CONSECUTIVE_FAILURES_REQUIRED="2"
RECOVERY_NOTIFICATIONS="true"
```

---

# Configuration Options

## BOT_TOKEN

Your Telegram Bot API token.

Required.

Example:

```text
123456789:AAxxxxxxxxxxxxxxxxxxxxxxxx
```

Obtain this from **BotFather**.

---

## CHAT_ID

Your Telegram chat ID.

Required.

Example:

```text
476206222
```

---

## DOWNLOAD_THRESHOLD_MBPS

Minimum acceptable download speed before the connection is considered degraded.

Default:

```text
600
```

Example:

If a speed test returns:

```text
540 Mbps
```

the monitor records the result as degraded.

---

## LATENCY_THRESHOLD_MS

Maximum acceptable latency.

Default:

```text
30
```

Example:

```text
42 ms
```

will trigger a degraded result.

---

## SPEEDTEST_SERVER_ID

The Ookla server used for testing.

Current example:

```text
30690
```

Community Fibre – London

To find available servers:

```bash
speedtest-go --list
```

---

## NOTIFY_ON_SUCCESS

Controls whether every successful scheduled speed test sends a Telegram message.

Options:

```text
true
false
```

Recommended:

```text
false
```

Instead of receiving multiple healthy notifications each day, the project sends a single Daily Summary while still notifying immediately about problems.

---

## CONSECUTIVE_FAILURES_REQUIRED

Number of consecutive degraded speed tests required before an alert is sent.

Default:

```text
2
```

This helps avoid alerts caused by temporary network fluctuations.

---

## RECOVERY_NOTIFICATIONS

Send a Telegram notification when network performance returns to normal.

Options:

```text
true
false
```

Recommended:

```text
true
```

---

# Configuration Workflow

1. Install the project

```bash
./install.sh
```

2. Edit the configuration

```bash
sudo nano /opt/home-network-monitor/config.conf
```

3. Save the file.

4. Re-run the installer if scripts have been updated.

```bash
./install.sh
```

---

# Security

Never commit your real configuration file.

Only commit:

```text
config/config.example.conf
```

Your real configuration contains sensitive information including:

- Telegram Bot Token
- Telegram Chat ID

These should always remain private.

---

# Best Practices

Recommended production configuration:

```bash
DOWNLOAD_THRESHOLD_MBPS="600"
LATENCY_THRESHOLD_MS="30"

NOTIFY_ON_SUCCESS="false"

CONSECUTIVE_FAILURES_REQUIRED="2"

RECOVERY_NOTIFICATIONS="true"
```

This provides:

- Immediate degradation alerts
- Recovery notifications
- One daily summary
- Reduced notification spam
