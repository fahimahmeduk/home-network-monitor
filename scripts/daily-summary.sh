#!/usr/bin/env bash

set -u
set -o pipefail

BASE="${HOME_NETWORK_MONITOR_BASE:-/opt/home-network-monitor}"
CONFIG_FILE="$BASE/config.conf"
SPEED_LOG="$BASE/logs/speed.csv"
INTERNET_LOG="$BASE/logs/internet.log"

if [[ ! -r "$CONFIG_FILE" ]]; then
    echo "Configuration file is missing or unreadable: $CONFIG_FILE" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

send_telegram() {
    local message="$1"

    if [[ -z "${BOT_TOKEN:-}" || -z "${CHAT_ID:-}" ]]; then
        return 0
    fi

    curl -fsS --max-time 15 \
        -X POST \
        "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        --data-urlencode "text=${message}" \
        >/dev/null || true
}

TODAY="$(date '+%Y-%m-%d')"
DISPLAY_TIME="$(date '+%H:%M')"
EXPECTED_HEADER="timestamp,download_mbps,upload_mbps,latency_ms,packet_loss_percent,packet_loss_source,health_score,isp,server,status,attempts,reason"

if [[ -f "$SPEED_LOG" ]] && \
   [[ "$(head -n 1 "$SPEED_LOG" 2>/dev/null || true)" != "$EXPECTED_HEADER" ]]; then
    send_telegram "📊 Home Network Daily Summary

⚠️ The speed log is still using the v1.2 format.

Run 'network-monitor speed' once to migrate the log safely.

🕒 ${DISPLAY_TIME}"
    exit 1
fi

if [[ ! -s "$SPEED_LOG" ]] || [[ "$(wc -l < "$SPEED_LOG")" -le 1 ]]; then
    send_telegram "📊 Home Network Daily Summary

⚠️ No speed-test results are available for today.

🕒 ${DISPLAY_TIME}"
    exit 1
fi

SUMMARY="$(
    awk -F',' -v today="$TODAY" '
        NR == 1 { next }
        {
            timestamp = $1
            gsub(/^"|"$/, "", timestamp)
            if (substr(timestamp, 1, 10) != today) next

            checks++
            latest_status = $10
            latest_isp = $8
            latest_server = $9
            gsub(/^"|"$/, "", latest_isp)
            gsub(/^"|"$/, "", latest_server)

            if ($2 != "" && $2 >= 0 &&
                $3 != "" && $3 >= 0 &&
                $4 != "" && $4 >= 0) {
                valid++
                download_total += $2
                upload_total += $3
                latency_total += $4
                health_score_total += $7
            }

            if ($5 != "" && $5 >= 0) {
                packet_loss_count++
                packet_loss_total += $5
            }
        }
        END {
            if (valid > 0) {
                download_average = download_total / valid
                upload_average = upload_total / valid
                latency_average = latency_total / valid
                health_score_average = health_score_total / valid
            } else {
                download_average = -1
                upload_average = -1
                latency_average = -1
                health_score_average = -1
            }

            if (packet_loss_count > 0) {
                packet_loss_average = packet_loss_total / packet_loss_count
            } else {
                packet_loss_average = -1
            }

            printf "%d|%d|%.2f|%.2f|%.2f|%.2f|%.0f|%s|%s|%s", \
                checks, valid, download_average, upload_average, \
                latency_average, packet_loss_average, health_score_average, \
                latest_status, latest_isp, latest_server
        }
    ' "$SPEED_LOG"
)"

IFS='|' read -r \
    TOTAL_SPEED_CHECKS \
    VALID_SPEED_CHECKS \
    DOWNLOAD_AVERAGE \
    UPLOAD_AVERAGE \
    LATENCY_AVERAGE \
    PACKET_LOSS_AVERAGE \
    HEALTH_SCORE_AVERAGE \
    LATEST_STATUS \
    LATEST_ISP \
    LATEST_SERVER \
    <<< "$SUMMARY"

if [[ "$TOTAL_SPEED_CHECKS" -eq 0 ]]; then
    send_telegram "📊 Home Network Daily Summary

⚠️ No speed-test results are available for today.

🕒 ${DISPLAY_TIME}"
    exit 1
fi

TOTAL_CHECKS=0
UP_CHECKS=0

if compgen -G "$BASE/logs/internet*.log" >/dev/null; then
    TOTAL_CHECKS="$(
        grep -h "^${TODAY} " "$BASE"/logs/internet*.log 2>/dev/null |
            wc -l
    )"
    UP_CHECKS="$(
        grep -h "^${TODAY} " "$BASE"/logs/internet*.log 2>/dev/null |
            grep -c ',UP$' || true
    )"
fi

if [[ "$TOTAL_CHECKS" -gt 0 ]]; then
    UPTIME_PERCENT="$(
        awk -v up="$UP_CHECKS" -v total="$TOTAL_CHECKS" \
            'BEGIN { printf "%.2f", (up / total) * 100 }'
    )"
else
    UPTIME_PERCENT="N/A"
fi

format_average() {
    local value="$1"
    local decimals="$2"

    if awk -v value="$value" 'BEGIN { exit !(value < 0) }'; then
        printf '%s' "N/A"
    else
        awk -v value="$value" -v decimals="$decimals" \
            'BEGIN { printf "%.*f", decimals, value }'
    fi
}

DOWNLOAD_DISPLAY="$(format_average "$DOWNLOAD_AVERAGE" 0)"
UPLOAD_DISPLAY="$(format_average "$UPLOAD_AVERAGE" 0)"
LATENCY_DISPLAY="$(format_average "$LATENCY_AVERAGE" 0)"
PACKET_LOSS_DISPLAY="$(format_average "$PACKET_LOSS_AVERAGE" 2)"
HEALTH_SCORE_DISPLAY="$(format_average "$HEALTH_SCORE_AVERAGE" 0)"
if [[ "$PACKET_LOSS_DISPLAY" == "N/A" ]]; then
    PACKET_LOSS_TEXT="N/A"
else
    PACKET_LOSS_TEXT="${PACKET_LOSS_DISPLAY}%"
fi
SERVER_DISPLAY="${LATEST_SERVER% Limited}"

health_label() {
    local score="$1"

    if [[ "$score" == "N/A" ]]; then
        printf '%s' "Unavailable"
    elif [[ "$score" -ge 90 ]]; then
        printf '%s' "Excellent"
    elif [[ "$score" -ge 75 ]]; then
        printf '%s' "Good"
    elif [[ "$score" -ge 50 ]]; then
        printf '%s' "Fair"
    else
        printf '%s' "Poor"
    fi
}

HEALTH_LABEL="$(health_label "$HEALTH_SCORE_DISPLAY")"

case "$LATEST_STATUS" in
healthy)
    STATUS_LINE="🟢 Healthy"
    ;;
degraded)
    STATUS_LINE="🟠 Performance Degraded"
    ;;
error)
    STATUS_LINE="🔴 Latest speed test failed"
    ;;
*)
    STATUS_LINE="⚪ Status unavailable"
    ;;
esac

send_telegram "📊 Home Network Daily Summary

${STATUS_LINE}

⬇️ Average download: ${DOWNLOAD_DISPLAY} Mbps
⬆️ Average upload: ${UPLOAD_DISPLAY} Mbps
📶 Average latency: ${LATENCY_DISPLAY} ms
📦 Average packet loss: ${PACKET_LOSS_TEXT}
❤️ Average health score: ${HEALTH_SCORE_DISPLAY}/100 (${HEALTH_LABEL})
🏢 ISP: ${LATEST_ISP}
🌐 Latest server: ${SERVER_DISPLAY}

🧪 Speed checks: ${VALID_SPEED_CHECKS}/${TOTAL_SPEED_CHECKS} successful
⏱️ Today's uptime: ${UPTIME_PERCENT}%

🕒 ${DISPLAY_TIME}"
