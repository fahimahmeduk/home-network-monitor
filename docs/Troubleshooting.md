# Troubleshooting

## Start with status

```bash
network-monitor version
network-monitor status
network-monitor logs
```

## Configuration is unreadable

Check ownership and permissions without displaying its contents:

```bash
ls -l /opt/home-network-monitor/config.conf
```

Run the installer again from the repository. It restores ownership to the installing user and mode `0600` while preserving values.

## Telegram test fails

```bash
network-monitor test-telegram
```

Check:

- The bot token is correct
- The chat ID is correct
- The bot has received an initial message
- Outbound HTTPS to `api.telegram.org` is available

Never paste the live token into an issue or support conversation.

## Connectivity shows DOWN while browsing works

One or more public hosts may ignore ICMP.

Test each configured target:

```bash
ping -c 5 8.8.8.8
ping -c 5 1.1.1.1
```

Set `CONNECTIVITY_TARGETS` to at least two targets that respond reliably from the monitoring server.

## Packet loss shows N/A

Test the configured host:

```bash
ping -c 20 -i 0.2 -W 1 8.8.8.8
```

If it does not respond, change `PACKET_LOSS_HOST`. Do not treat a host that blocks ICMP as genuine 100% packet loss.

## Primary result is poor but fallback is healthy

This is expected confirmation behaviour. `network-monitor status` records the initial assessment, final server and attempt count.

Review the primary server if this happens consistently. A test server can have poor upload capacity even when the broadband connection is healthy.

## ISP name is incorrect

Compare the host's actual public network with the stored speed result:

```bash
curl -4 -fsS https://ipinfo.io/org
network-monitor status
```

The monitor uses the independent lookup first because Speedtest metadata can occasionally identify the caller incorrectly. It falls back to Speedtest metadata if the lookup is unavailable.

If the independent lookup is also wrong, set an explicit provider name in the private configuration:

```bash
ISP_NAME_OVERRIDE="Your ISP name"
```

Do not publish the public IP address while troubleshooting.

## Status reports a previous log format

Run one v1.3 speed test:

```bash
network-monitor speed
```

The old CSV is archived safely and a new schema is created.

## Speed test takes several minutes

A poor or failed primary result triggers:

1. A configured wait, normally 60 seconds
2. A second full test through the fallback server
3. A final threshold assessment

This is normal and reduces false alerts.

## Scheduled checks are missing

```bash
crontab -l | grep HOME-NETWORK-MONITOR
```

Run `./install.sh` again to recreate the entries idempotently.

## No speed data in the daily summary

Confirm that a speed test has completed today:

```bash
tail -n 5 /opt/home-network-monitor/logs/speed.csv
```

Then run:

```bash
network-monitor summary
```

## Inspect without exposing secrets

Safe commands:

```bash
network-monitor status
network-monitor logs
crontab -l | grep HOME-NETWORK-MONITOR
```

Do not publish:

- `/opt/home-network-monitor/config.conf`
- Telegram API responses containing account information
- Public IP addresses
- Bot tokens or chat IDs
