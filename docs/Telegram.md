# Telegram Notifications

Home Network Monitor uses the Telegram Bot API to deliver real-time notifications about the health of your home internet connection.

Notifications are designed to be lightweight, informative, and easy to read on a mobile device.

---

# Notification Types

The project currently supports five notification types.

- Test Notification
- Daily Network Summary
- Performance Degraded
- Performance Restored
- Speed Test Failed

---

# Test Notification

Used to verify that Telegram has been configured correctly.

Run:

```bash
network-monitor test-telegram
```

Expected result:

```text
✅ Home Network Monitor

Telegram configuration successful.
```

---

# Daily Network Summary

Sent once per day.

Default schedule:

```text
20:05
```

Example:

```text
📊 Home Network Daily Summary

🟢 Healthy

⬇️ Download: 831 Mbps
📶 Latency: 5 ms
🌐 Server: Community Fibre
⏱️ Today's uptime: 100.00%

🕒 20:05
```

Purpose:

- Provides a quick overview of the day's network performance.
- Confirms that monitoring is operational.
- Avoids sending multiple routine notifications throughout the day.

---

# Performance Degraded

Sent when the configured number of consecutive degraded speed tests has been reached.

Example:

```text
📊 Home Network Status

🟠 Performance Degraded

⬇️ Download: 482 Mbps
📶 Latency: 42 ms
🌐 Server: Community Fibre

⚠️ Poor tests: 2

🕒 20:00
```

This prevents alerts from being triggered by a single temporary fluctuation.

---

# Performance Restored

Sent after the connection returns to normal following a degraded state.

Example:

```text
📊 Home Network Status

🟢 Restored

⬇️ Download: 824 Mbps
📶 Latency: 5 ms
🌐 Server: Community Fibre

🕒 20:15
```

This confirms that network performance has recovered.

---

# Speed Test Failed

Sent if the speed test cannot complete successfully.

Possible causes include:

- Internet outage
- Speedtest server unavailable
- Invalid response
- Missing dependency

Example:

```text
⚠️ Home Network Speed Test Failed

No result was returned.

🕒 20:00
```

---

# Notification Philosophy

The project is designed to minimise notification fatigue.

Instead of sending a message after every successful speed test, the monitor provides:

- Immediate alerts when something is wrong.
- Recovery notifications when the issue is resolved.
- A single Daily Network Summary for routine reporting.

This approach keeps Telegram informative without becoming noisy.

---

# Telegram Configuration

Configuration is stored in:

```text
/opt/home-network-monitor/config.conf
```

Required settings:

```bash
BOT_TOKEN="YOUR_BOT_TOKEN"
CHAT_ID="YOUR_CHAT_ID"
```

Never commit your real configuration file to Git.

Only commit:

```text
config/config.example.conf
```

---

# Screenshots

The following screenshots are recommended for the repository.

- Telegram Test Message
- Daily Network Summary
- Performance Degraded
- Performance Restored

These demonstrate the different notification types without exposing any sensitive information.
