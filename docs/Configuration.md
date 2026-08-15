# Configuration

The live configuration file is:

```text
/opt/home-network-monitor/config.conf
```

Edit it with:

```bash
sudo nano /opt/home-network-monitor/config.conf
```

The installer preserves existing values and adds missing settings during upgrades.

## Telegram

| Setting | Required | Description |
|---|---|---|
| `BOT_TOKEN` | Yes | Token created for the Telegram bot |
| `CHAT_ID` | Yes | Destination user, group or channel ID |

Never commit these values or include them in screenshots.

## Performance thresholds

| Setting | Default | Meaning |
|---|---:|---|
| `DOWNLOAD_THRESHOLD_MBPS` | `600` | Minimum healthy download speed |
| `UPLOAD_THRESHOLD_MBPS` | `600` | Minimum healthy upload speed |
| `LATENCY_THRESHOLD_MS` | `30` | Maximum healthy idle latency |
| `PACKET_LOSS_THRESHOLD_PERCENT` | `2` | Maximum healthy packet loss |

Thresholds should reflect the subscribed connection and normal observed performance. Avoid setting them equal to the advertised maximum because ordinary variation could produce false alerts.

## Speed testing

| Setting | Default | Meaning |
|---|---:|---|
| `SPEEDTEST_SERVER_ID` | `30690` | Primary test server |
| `SPEEDTEST_FALLBACK_SERVER_ID` | `54208` | Confirmation server |
| `SPEEDTEST_BINARY` | `/usr/local/bin/speedtest-go` | Binary path |
| `SPEEDTEST_MAX_ATTEMPTS` | `2` | Maximum attempts per scheduled run |
| `SPEEDTEST_RETRY_DELAY_SECONDS` | `60` | Wait before confirmation |

The included server IDs are UK examples. Find reliable nearby servers for other locations.

Using two independent servers helps distinguish an ISP issue from an overloaded or unsuitable test server.

## ISP detection

| Setting | Default | Meaning |
|---|---:|---|
| `ISP_NAME_OVERRIDE` | Empty | Explicit provider name; takes highest priority when set |
| `ISP_LOOKUP_ENABLED` | `true` | Use an independent HTTPS lookup instead of relying only on Speedtest metadata |
| `ISP_LOOKUP_URL` | `https://ipinfo.io/org` | Endpoint expected to return an ASN and organisation name |
| `ISP_LOOKUP_TIMEOUT_SECONDS` | `10` | Maximum lookup time before falling back to Speedtest metadata |

The lookup response has a leading ASN removed before the provider name is stored. If the lookup is unavailable, the monitor falls back to the ISP value returned by `speedtest-go`. Set `ISP_NAME_OVERRIDE` when either external source identifies the connection incorrectly.

## Packet loss

| Setting | Default | Meaning |
|---|---:|---|
| `PACKET_LOSS_HOST` | `8.8.8.8` | Ping target used when Speedtest packet-loss data is unavailable |
| `PACKET_LOSS_PING_COUNT` | `20` | Packets per probe |
| `PACKET_LOSS_PING_INTERVAL_SECONDS` | `0.2` | Delay between packets |
| `PACKET_LOSS_PING_TIMEOUT_SECONDS` | `1` | Per-packet timeout |

Some public targets deliberately ignore ICMP. Confirm that the selected host responds from the monitoring server:

```bash
ping -c 5 8.8.8.8
```

If the target does not respond, choose another stable target rather than treating the result as genuine packet loss.

## Connectivity

| Setting | Default | Meaning |
|---|---:|---|
| `CONNECTIVITY_TARGETS` | `8.8.8.8 1.1.1.1` | Space-separated targets tried in order |
| `CONNECTIVITY_PING_COUNT` | `2` | Packets sent to each target |
| `CONNECTIVITY_PING_TIMEOUT_SECONDS` | `3` | Per-packet timeout |

The connection is considered available as soon as one target responds.

## Notifications

| Setting | Default | Meaning |
|---|---:|---|
| `NOTIFY_ON_SUCCESS` | `false` | Send a message after every healthy speed test |
| `RECOVERY_NOTIFICATIONS` | `true` | Notify when performance recovers |

Keeping `NOTIFY_ON_SUCCESS` disabled reduces noise. The scheduled daily summary still confirms normal operation.

## Log management

| Setting | Default | Meaning |
|---|---:|---|
| `LOG_MAX_SIZE_BYTES` | `1048576` | Rotate a log at 1 MiB |
| `LOG_RETENTION_DAYS` | `90` | Retain rotated archives |

## Example

```bash
BOT_TOKEN="YOUR_TELEGRAM_BOT_TOKEN"
CHAT_ID="YOUR_TELEGRAM_CHAT_ID"

DOWNLOAD_THRESHOLD_MBPS="600"
UPLOAD_THRESHOLD_MBPS="600"
LATENCY_THRESHOLD_MS="30"
PACKET_LOSS_THRESHOLD_PERCENT="2"

SPEEDTEST_SERVER_ID="30690"
SPEEDTEST_FALLBACK_SERVER_ID="54208"
SPEEDTEST_MAX_ATTEMPTS="2"
SPEEDTEST_RETRY_DELAY_SECONDS="60"

ISP_NAME_OVERRIDE=""
ISP_LOOKUP_ENABLED="true"
ISP_LOOKUP_URL="https://ipinfo.io/org"
ISP_LOOKUP_TIMEOUT_SECONDS="10"

PACKET_LOSS_HOST="8.8.8.8"
CONNECTIVITY_TARGETS="8.8.8.8 1.1.1.1"

NOTIFY_ON_SUCCESS="false"
RECOVERY_NOTIFICATIONS="true"
```

After editing, run:

```bash
network-monitor test-telegram
network-monitor check
network-monitor speed
network-monitor status
```
