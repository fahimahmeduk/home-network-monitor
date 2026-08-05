#!/usr/bin/env bash

set -u
set -o pipefail

BASE="/opt/home-network-monitor"
CONFIG_FILE="$BASE/config.conf"
SPEED_LOG="$BASE/logs/speed.csv"
INTERNET_LOG="$BASE/logs/internet.log"

source "$CONFIG_FILE"

send_telegram() {
    local message="$1"

    curl -fsS --max-time 15 \
        -X POST \
        "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        --data-urlencode "text=${message}" \
        >/dev/null || true
}

TODAY="$(date '+%Y-%m-%d')"
DISPLAY_TIME="$(date '+%H:%M')"

if [[ ! -s "$SPEED_LOG" ]]; then
    send_telegram "📊 Home Network Daily Summary

⚠️ No speed-test results are available.

🕒 ${DISPLAY_TIME}"
    exit 1
fi

LATEST_RESULT="$(tail -n 1 "$SPEED_LOG")"

DOWNLOAD_MBPS="$(awk -F',' '{print $2}' <<< "$LATEST_RESULT")"
LATENCY_MS="$(awk -F',' '{print $3}' <<< "$LATEST_RESULT")"
SERVER="$(awk -F',' '{gsub(/^"|"$/, "", $4); print $4}' <<< "$LATEST_RESULT")"
STATUS="$(awk -F',' '{print $5}' <<< "$LATEST_RESULT")"

DOWNLOAD_DISPLAY="$(awk "BEGIN {printf \"%.0f\", $DOWNLOAD_MBPS}")"
LATENCY_DISPLAY="$(awk "BEGIN {printf \"%.0f\", $LATENCY_MS}")"
SERVER_DISPLAY="${SERVER% Limited}"

if [[ -z "$STATUS" ]]; then
    DOWNLOAD_LOW="$(awk "BEGIN {print ($DOWNLOAD_MBPS < $DOWNLOAD_THRESHOLD_MBPS)}")"
    LATENCY_HIGH="$(awk "BEGIN {print ($LATENCY_MS > $LATENCY_THRESHOLD_MS)}")"

    if [[ "$DOWNLOAD_LOW" -eq 1 || "$LATENCY_HIGH" -eq 1 ]]; then
        STATUS="degraded"
    else
        STATUS="healthy"
    fi
fi

TOTAL_CHECKS="0"
UP_CHECKS="0"

if [[ -f "$INTERNET_LOG" ]]; then
    TOTAL_CHECKS="$(grep -c "^${TODAY} " "$INTERNET_LOG" 2>/dev/null || true)"
    UP_CHECKS="$(grep "^${TODAY} " "$INTERNET_LOG" 2>/dev/null | grep -c ',UP$' || true)"
fi

if [[ "$TOTAL_CHECKS" -gt 0 ]]; then
    UPTIME_PERCENT="$(awk "BEGIN {printf \"%.2f\", ($UP_CHECKS / $TOTAL_CHECKS) * 100}")"
else
    UPTIME_PERCENT="N/A"
fi

if [[ "$STATUS" == "healthy" ]]; then
    STATUS_LINE="🟢 Healthy"
else
    STATUS_LINE="🟠 Performance Degraded"
fi

send_telegram "📊 Home Network Daily Summary

${STATUS_LINE}

⬇️ Download: ${DOWNLOAD_DISPLAY} Mbps
📶 Latency: ${LATENCY_DISPLAY} ms
🌐 Server: ${SERVER_DISPLAY}
⏱️ Today's uptime: ${UPTIME_PERCENT}%

🕒 ${DISPLAY_TIME}"
