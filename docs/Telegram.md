# Telegram setup

Home Network Monitor uses a Telegram bot for test messages, performance alerts, recovery notifications and daily summaries.

## Create a bot

1. Open Telegram and start a conversation with `@BotFather`.
2. Use `/newbot`.
3. Follow the prompts to choose a display name and username.
4. Store the bot token securely.

## Obtain the chat ID

1. Open the new bot and send it a message.
2. Use Telegram's Bot API `getUpdates` method or another trusted chat-ID method.
3. Record the numeric chat ID.

Do not paste bot tokens or chat IDs into public issues, screenshots or documentation.

## Configure

```bash
sudo nano /opt/home-network-monitor/config.conf
```

Set:

```bash
BOT_TOKEN="YOUR_TELEGRAM_BOT_TOKEN"
CHAT_ID="YOUR_TELEGRAM_CHAT_ID"
```

Test it:

```bash
network-monitor test-telegram
```

Successful output:

```text
Telegram test message sent successfully.
```

## Notification behaviour

| Event | Notification |
|---|---|
| Connectivity goes down | Stored locally; Telegram cannot send while offline |
| Connectivity returns | Restoration message with approximate downtime |
| Performance is confirmed degraded | Metrics, Health Score, ISP, server and assessment |
| Performance recovers | Recovery metrics |
| Speed test repeatedly fails | One error notification per error state |
| Daily schedule | Daily averages and uptime |

Repeated alerts are suppressed while the state remains unchanged.

## Security

The installed configuration is mode `0600`. Keep it outside the Git repository and rotate the token immediately if it is exposed.
