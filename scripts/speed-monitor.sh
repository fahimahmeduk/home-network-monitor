#!/usr/bin/env bash

set -u
set -o pipefail

BASE="/opt/home-network-monitor"
CONFIG_FILE="$BASE/config.conf"
LOG_FILE="$BASE/logs/speed.csv"
STATE_FILE="$BASE/state/speed.state"
FAIL_COUNT_FILE="$BASE/state/speed.failcount"

source "$CONFIG_FILE"

NOTIFY_ON_SUCCESS="${NOTIFY_ON_SUCCESS:-false}"
CONSECUTIVE_FAILURES_REQUIRED="${CONSECUTIVE_FAILURES_REQUIRED:-2}"
RECOVERY_NOTIFICATIONS="${RECOVERY_NOTIFICATIONS:-true}"

send_telegram() {
    local message="$1"

    curl -fsS --max-time 15 \
        -X POST \
        "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        --data-urlencode "text=${message}" \
        >/dev/null || true
}

NOW="$(date '+%Y-%m-%d %H:%M:%S')"
DISPLAY_TIME="$(date '+%H:%M')"
PREVIOUS_STATE="$(cat "$STATE_FILE" 2>/dev/null || echo unknown)"
FAIL_COUNT="$(cat "$FAIL_COUNT_FILE" 2>/dev/null || echo 0)"

RESULT="$(
    timeout 180 /usr/local/bin/speedtest-go \
        --server "$SPEEDTEST_SERVER_ID" \
        --json 2>/dev/null || true
)"

if [[ -z "$RESULT" ]]; then
    send_telegram "⚠️ Home Network Speed Test Failed

No result was returned.

🕒 ${DISPLAY_TIME}"
    exit 1
fi

DOWNLOAD_BYTES="$(jq -r '.servers[0].dl_speed // -1' <<< "$RESULT")"
LATENCY_NS="$(jq -r '.servers[0].latency // -1' <<< "$RESULT")"
SERVER="$(jq -r '.servers[0].sponsor // "Unknown server"' <<< "$RESULT")"

if [[ "$DOWNLOAD_BYTES" == "-1" || "$LATENCY_NS" == "-1" ]]; then
    send_telegram "⚠️ Home Network Speed Test Failed

The result could not be parsed.

🕒 ${DISPLAY_TIME}"
    exit 1
fi

DOWNLOAD_MBPS="$(
    awk "BEGIN { printf \"%.2f\", ($DOWNLOAD_BYTES * 8) / 1000000 }"
)"

LATENCY_MS="$(
    awk "BEGIN { printf \"%.2f\", $LATENCY_NS / 1000000 }"
)"

DOWNLOAD_DISPLAY="$(
    awk "BEGIN { printf \"%.0f\", $DOWNLOAD_MBPS }"
)"

LATENCY_DISPLAY="$(
    awk "BEGIN { printf \"%.0f\", $LATENCY_MS }"
)"

SERVER_DISPLAY="${SERVER% Limited}"

mkdir -p "$BASE/logs" "$BASE/state"

if [[ ! -f "$LOG_FILE" ]]; then
    echo "timestamp,download_mbps,latency_ms,server,status" > "$LOG_FILE"
fi

DOWNLOAD_LOW="$(
    awk "BEGIN { print ($DOWNLOAD_MBPS < $DOWNLOAD_THRESHOLD_MBPS) }"
)"

LATENCY_HIGH="$(
    awk "BEGIN { print ($LATENCY_MS > $LATENCY_THRESHOLD_MS) }"
)"

if [[ "$DOWNLOAD_LOW" -eq 1 || "$LATENCY_HIGH" -eq 1 ]]; then
    STATUS="degraded"
else
    STATUS="healthy"
fi

echo "\"$NOW\",$DOWNLOAD_MBPS,$LATENCY_MS,\"$SERVER\",$STATUS" >> "$LOG_FILE"

if [[ "$STATUS" == "degraded" ]]; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "$FAIL_COUNT" > "$FAIL_COUNT_FILE"

    if [[ "$FAIL_COUNT" -ge "$CONSECUTIVE_FAILURES_REQUIRED" && "$PREVIOUS_STATE" != "degraded" ]]; then
        echo "degraded" > "$STATE_FILE"

        send_telegram "📊 Home Network Status

🟠 Performance Degraded

⬇️ Download: ${DOWNLOAD_DISPLAY} Mbps
📶 Latency: ${LATENCY_DISPLAY} ms
🌐 Server: ${SERVER_DISPLAY}

⚠️ Poor tests: ${FAIL_COUNT}
🕒 ${DISPLAY_TIME}"
    fi
else
    echo "0" > "$FAIL_COUNT_FILE"
    echo "healthy" > "$STATE_FILE"

    if [[ "$PREVIOUS_STATE" == "degraded" && "$RECOVERY_NOTIFICATIONS" == "true" ]]; then
        send_telegram "📊 Home Network Status

🟢 Restored

⬇️ Download: ${DOWNLOAD_DISPLAY} Mbps
📶 Latency: ${LATENCY_DISPLAY} ms
🌐 Server: ${SERVER_DISPLAY}

🕒 ${DISPLAY_TIME}"

    elif [[ "$NOTIFY_ON_SUCCESS" == "true" ]]; then
        send_telegram "📊 Home Network Status

🟢 Healthy

⬇️ Download: ${DOWNLOAD_DISPLAY} Mbps
📶 Latency: ${LATENCY_DISPLAY} ms
🌐 Server: ${SERVER_DISPLAY}

🕒 ${DISPLAY_TIME}"
    fi
fi
