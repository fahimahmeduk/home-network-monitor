#!/usr/bin/env bash

set -u
set -o pipefail

BASE="${HOME_NETWORK_MONITOR_BASE:-/opt/home-network-monitor}"
CONFIG_FILE="$BASE/config.conf"
LOG_FILE="$BASE/logs/speed.csv"
STATE_FILE="$BASE/state/speed.state"
LOCK_FILE="$BASE/state/speed.lock"
CSV_HEADER="timestamp,download_mbps,upload_mbps,latency_ms,packet_loss_percent,packet_loss_source,health_score,isp,server,status,attempts,reason"

if [[ ! -r "$CONFIG_FILE" ]]; then
    echo "Configuration file is missing or unreadable: $CONFIG_FILE" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

DOWNLOAD_THRESHOLD_MBPS="${DOWNLOAD_THRESHOLD_MBPS:-600}"
UPLOAD_THRESHOLD_MBPS="${UPLOAD_THRESHOLD_MBPS:-600}"
LATENCY_THRESHOLD_MS="${LATENCY_THRESHOLD_MS:-30}"
PACKET_LOSS_THRESHOLD_PERCENT="${PACKET_LOSS_THRESHOLD_PERCENT:-2}"
SPEEDTEST_MAX_ATTEMPTS="${SPEEDTEST_MAX_ATTEMPTS:-2}"
SPEEDTEST_RETRY_DELAY_SECONDS="${SPEEDTEST_RETRY_DELAY_SECONDS:-60}"
SPEEDTEST_SERVER_ID="${SPEEDTEST_SERVER_ID:-}"
SPEEDTEST_FALLBACK_SERVER_ID="${SPEEDTEST_FALLBACK_SERVER_ID:-}"
SPEEDTEST_BINARY="${SPEEDTEST_BINARY:-/usr/local/bin/speedtest-go}"
PACKET_LOSS_HOST="${PACKET_LOSS_HOST:-8.8.8.8}"
PACKET_LOSS_PING_COUNT="${PACKET_LOSS_PING_COUNT:-20}"
PACKET_LOSS_PING_INTERVAL_SECONDS="${PACKET_LOSS_PING_INTERVAL_SECONDS:-0.2}"
PACKET_LOSS_PING_TIMEOUT_SECONDS="${PACKET_LOSS_PING_TIMEOUT_SECONDS:-1}"
LOG_MAX_SIZE_BYTES="${LOG_MAX_SIZE_BYTES:-1048576}"
LOG_RETENTION_DAYS="${LOG_RETENTION_DAYS:-90}"
NOTIFY_ON_SUCCESS="${NOTIFY_ON_SUCCESS:-false}"
RECOVERY_NOTIFICATIONS="${RECOVERY_NOTIFICATIONS:-true}"
ISP_NAME_OVERRIDE="${ISP_NAME_OVERRIDE:-}"
ISP_LOOKUP_ENABLED="${ISP_LOOKUP_ENABLED:-true}"
ISP_LOOKUP_URL="${ISP_LOOKUP_URL:-https://ipinfo.io/org}"
ISP_LOOKUP_TIMEOUT_SECONDS="${ISP_LOOKUP_TIMEOUT_SECONDS:-10}"

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

is_number() {
    [[ "$1" =~ ^-?[0-9]+([.][0-9]+)?([eE][+-]?[0-9]+)?$ ]]
}

validate_configuration() {
    local setting=""

    for setting in \
        DOWNLOAD_THRESHOLD_MBPS \
        UPLOAD_THRESHOLD_MBPS \
        LATENCY_THRESHOLD_MS \
        PACKET_LOSS_THRESHOLD_PERCENT; do
        if ! is_number "${!setting}" || \
           awk -v value="${!setting}" 'BEGIN { exit !(value <= 0) }'; then
            echo "Invalid positive numeric setting: $setting" >&2
            exit 1
        fi
    done

    if [[ ! "$SPEEDTEST_MAX_ATTEMPTS" =~ ^[1-9][0-9]*$ ]]; then
        echo "SPEEDTEST_MAX_ATTEMPTS must be a positive integer." >&2
        exit 1
    fi

    if [[ ! "$SPEEDTEST_RETRY_DELAY_SECONDS" =~ ^[0-9]+$ ]]; then
        echo "SPEEDTEST_RETRY_DELAY_SECONDS must be a non-negative integer." >&2
        exit 1
    fi

    if [[ ! "$PACKET_LOSS_PING_COUNT" =~ ^[1-9][0-9]*$ ]]; then
        echo "PACKET_LOSS_PING_COUNT must be a positive integer." >&2
        exit 1
    fi

    if ! is_number "$PACKET_LOSS_PING_INTERVAL_SECONDS" || \
       ! is_number "$PACKET_LOSS_PING_TIMEOUT_SECONDS"; then
        echo "Packet-loss ping interval and timeout must be numeric." >&2
        exit 1
    fi

    if [[ ! "$LOG_MAX_SIZE_BYTES" =~ ^[1-9][0-9]*$ ]] || \
       [[ ! "$LOG_RETENTION_DAYS" =~ ^[1-9][0-9]*$ ]]; then
        echo "Log size and retention settings must be positive integers." >&2
        exit 1
    fi

    if [[ "$ISP_LOOKUP_ENABLED" != "true" && \
          "$ISP_LOOKUP_ENABLED" != "false" ]]; then
        echo "ISP_LOOKUP_ENABLED must be true or false." >&2
        exit 1
    fi

    if [[ ! "$ISP_LOOKUP_TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]]; then
        echo "ISP_LOOKUP_TIMEOUT_SECONDS must be a positive integer." >&2
        exit 1
    fi

    if [[ ! -x "$SPEEDTEST_BINARY" ]]; then
        echo "speedtest-go is missing or not executable: $SPEEDTEST_BINARY" >&2
        exit 1
    fi
}

prepare_speed_log() {
    local existing_header=""
    local archive_file=""

    if [[ -f "$LOG_FILE" ]]; then
        IFS= read -r existing_header < "$LOG_FILE" || true
    fi

    if [[ -n "$existing_header" && "$existing_header" != "$CSV_HEADER" ]]; then
        archive_file="$BASE/logs/speed-legacy-$(date '+%Y%m%d-%H%M%S').csv"
        mv "$LOG_FILE" "$archive_file"
        echo "Previous-format speed log archived to: $archive_file"
    fi

    if [[ ! -f "$LOG_FILE" ]]; then
        printf '%s\n' "$CSV_HEADER" > "$LOG_FILE"
    fi
}

rotate_speed_log() {
    local size=0
    local archive_file=""

    if [[ -f "$LOG_FILE" ]]; then
        size="$(wc -c < "$LOG_FILE")"
    fi

    if [[ "$size" -ge "$LOG_MAX_SIZE_BYTES" ]]; then
        archive_file="$BASE/logs/speed-$(date '+%Y%m%d-%H%M%S').csv"
        mv "$LOG_FILE" "$archive_file"
        echo "Speed log rotated to: $archive_file"
    fi

    find "$BASE/logs" \
        -maxdepth 1 \
        -type f \
        -name 'speed-*.csv' \
        -mtime "+$LOG_RETENTION_DAYS" \
        -delete 2>/dev/null || true
}

sanitize_csv_text() {
    tr ',"\r\n' '    ' <<< "$1" | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//'
}

resolve_isp() {
    local speedtest_isp="$1"
    local lookup_result=""

    if [[ -n "$ISP_NAME_OVERRIDE" ]]; then
        ISP="$ISP_NAME_OVERRIDE"
        return
    fi

    if [[ "$ISP_LOOKUP_ENABLED" == "true" && -n "$ISP_LOOKUP_URL" ]]; then
        lookup_result="$(
            curl -4 -fsS \
                --max-time "$ISP_LOOKUP_TIMEOUT_SECONDS" \
                "$ISP_LOOKUP_URL" 2>/dev/null || true
        )"
        lookup_result="$(
            sed -nE \
                '1{s/^AS[0-9]+[[:space:]]+//; s/[[:space:]]+$//; p;}' \
                <<< "$lookup_result"
        )"

        if [[ -n "$lookup_result" ]]; then
            ISP="$lookup_result"
            return
        fi
    fi

    if [[ -n "$speedtest_isp" && "$speedtest_isp" != "null" ]]; then
        ISP="$speedtest_isp"
    else
        ISP="Unknown ISP"
    fi
}

calculate_packet_loss() {
    local sent="$1"
    local duplicates="$2"
    local maximum="$3"

    awk -v sent="$sent" -v duplicates="$duplicates" -v maximum="$maximum" '
        BEGIN {
            if (maximum <= 0) {
                print "-1.00"
                exit
            }

            expected = maximum + 1
            unique_received = sent - duplicates
            lost = expected - unique_received

            if (lost < 0) lost = 0
            if (lost > expected) lost = expected

            printf "%.2f", (lost / expected) * 100
        }
    '
}

measure_ping_packet_loss() {
    local output=""
    local loss=""

    output="$(
        ping \
            -q \
            -c "$PACKET_LOSS_PING_COUNT" \
            -i "$PACKET_LOSS_PING_INTERVAL_SECONDS" \
            -W "$PACKET_LOSS_PING_TIMEOUT_SECONDS" \
            "$PACKET_LOSS_HOST" 2>/dev/null || true
    )"

    loss="$(
        sed -nE \
            's/.* ([0-9]+([.][0-9]+)?)% packet loss.*/\1/p' \
            <<< "$output" |
            tail -n 1
    )"

    if is_number "$loss"; then
        printf '%.2f' "$loss"
    else
        printf '%s' "-1.00"
    fi
}

calculate_health_score() {
    local weighted_total=""
    local available_weight=80
    local packet_weight=0

    if awk -v value="$PACKET_LOSS_PERCENT" 'BEGIN { exit !(value >= 0) }'; then
        packet_weight=20
        available_weight=100
    fi

    weighted_total="$(
        awk \
            -v download="$DOWNLOAD_MBPS" \
            -v download_threshold="$DOWNLOAD_THRESHOLD_MBPS" \
            -v upload="$UPLOAD_MBPS" \
            -v upload_threshold="$UPLOAD_THRESHOLD_MBPS" \
            -v latency="$LATENCY_MS" \
            -v latency_threshold="$LATENCY_THRESHOLD_MS" \
            -v loss="$PACKET_LOSS_PERCENT" \
            -v loss_threshold="$PACKET_LOSS_THRESHOLD_PERCENT" \
            -v packet_weight="$packet_weight" '
            function minimum(a, b) { return (a < b) ? a : b }
            BEGIN {
                download_score = minimum(100, (download / download_threshold) * 100)
                upload_score = minimum(100, (upload / upload_threshold) * 100)
                latency_score = (latency <= latency_threshold) \
                    ? 100 \
                    : minimum(100, (latency_threshold / latency) * 100)

                loss_score = 0
                if (packet_weight > 0) {
                    if (loss <= loss_threshold) {
                        loss_score = 100
                    } else {
                        loss_score = minimum(100, (loss_threshold / loss) * 100)
                    }
                }

                printf "%.2f", \
                    (download_score * 30) + \
                    (upload_score * 30) + \
                    (latency_score * 20) + \
                    (loss_score * packet_weight)
            }
        '
    )"

    HEALTH_SCORE="$(
        awk -v total="$weighted_total" -v weight="$available_weight" \
            'BEGIN { printf "%.0f", total / weight }'
    )"
}

health_label() {
    local score="$1"

    if [[ "$score" -ge 90 ]]; then
        printf '%s' "Excellent"
    elif [[ "$score" -ge 75 ]]; then
        printf '%s' "Good"
    elif [[ "$score" -ge 50 ]]; then
        printf '%s' "Fair"
    else
        printf '%s' "Poor"
    fi
}

run_speed_test() {
    local result=""
    local -a command=("$SPEEDTEST_BINARY")
    local selected_server="$SPEEDTEST_SERVER_ID"
    local download_bytes=""
    local upload_bytes=""
    local latency_ns=""
    local packet_sent=""
    local packet_dup=""
    local packet_max=""

    if [[ "$ATTEMPT" -gt 1 && -n "$SPEEDTEST_FALLBACK_SERVER_ID" ]]; then
        selected_server="$SPEEDTEST_FALLBACK_SERVER_ID"
    fi

    if [[ -n "$selected_server" ]]; then
        command+=(--server "$selected_server")
    fi
    command+=(--json)

    result="$(timeout 180 "${command[@]}" 2>/dev/null || true)"

    if [[ -z "$result" ]]; then
        TEST_ERROR="No result was returned"
        return 1
    fi

    download_bytes="$(jq -r '.servers[0].dl_speed // empty' <<< "$result")"
    upload_bytes="$(jq -r '.servers[0].ul_speed // empty' <<< "$result")"
    latency_ns="$(jq -r '.servers[0].latency // empty' <<< "$result")"
    packet_sent="$(jq -r '.servers[0].packet_loss.sent // 0' <<< "$result")"
    packet_dup="$(jq -r '.servers[0].packet_loss.dup // 0' <<< "$result")"
    packet_max="$(jq -r '.servers[0].packet_loss.max // 0' <<< "$result")"
    SERVER="$(jq -r '.servers[0].sponsor // "Unknown server"' <<< "$result")"
    ISP="$(
        jq -r \
            '.user_info.Isp // .user_info.isp // "Unknown ISP"' \
            <<< "$result"
    )"

    if ! is_number "$download_bytes" || \
       ! is_number "$upload_bytes" || \
       ! is_number "$latency_ns" || \
       ! is_number "$packet_sent" || \
       ! is_number "$packet_dup" || \
       ! is_number "$packet_max"; then
        TEST_ERROR="The speed-test result could not be parsed"
        return 1
    fi

    DOWNLOAD_MBPS="$(
        awk -v value="$download_bytes" \
            'BEGIN { printf "%.2f", (value * 8) / 1000000 }'
    )"

    UPLOAD_MBPS="$(
        awk -v value="$upload_bytes" \
            'BEGIN { printf "%.2f", (value * 8) / 1000000 }'
    )"

    LATENCY_MS="$(
        awk -v value="$latency_ns" \
            'BEGIN { printf "%.2f", value / 1000000 }'
    )"

    PACKET_LOSS_PERCENT="$(
        calculate_packet_loss "$packet_sent" "$packet_dup" "$packet_max"
    )"

    if awk -v value="$PACKET_LOSS_PERCENT" 'BEGIN { exit !(value < 0) }'; then
        PACKET_LOSS_PERCENT="$(measure_ping_packet_loss)"
        if awk -v value="$PACKET_LOSS_PERCENT" \
            'BEGIN { exit !(value >= 0) }'; then
            PACKET_LOSS_SOURCE="ping:${PACKET_LOSS_HOST}"
        else
            PACKET_LOSS_SOURCE="unavailable"
        fi
    else
        PACKET_LOSS_SOURCE="speedtest"
    fi

    SERVER="$(sanitize_csv_text "$SERVER")"
    ISP="$(sanitize_csv_text "$ISP")"
    PACKET_LOSS_SOURCE="$(sanitize_csv_text "$PACKET_LOSS_SOURCE")"
    TEST_ERROR=""
    return 0
}

evaluate_result() {
    local -a reasons=()
    local packet_loss_available=0

    if awk -v actual="$DOWNLOAD_MBPS" -v minimum="$DOWNLOAD_THRESHOLD_MBPS" \
        'BEGIN { exit !(actual < minimum) }'; then
        reasons+=("download below ${DOWNLOAD_THRESHOLD_MBPS} Mbps")
    fi

    if awk -v actual="$UPLOAD_MBPS" -v minimum="$UPLOAD_THRESHOLD_MBPS" \
        'BEGIN { exit !(actual < minimum) }'; then
        reasons+=("upload below ${UPLOAD_THRESHOLD_MBPS} Mbps")
    fi

    if awk -v actual="$LATENCY_MS" -v maximum="$LATENCY_THRESHOLD_MS" \
        'BEGIN { exit !(actual > maximum) }'; then
        reasons+=("latency above ${LATENCY_THRESHOLD_MS} ms")
    fi

    packet_loss_available="$(
        awk -v actual="$PACKET_LOSS_PERCENT" 'BEGIN { print (actual >= 0) }'
    )"

    if [[ "$packet_loss_available" -eq 1 ]] && \
       awk -v actual="$PACKET_LOSS_PERCENT" \
           -v maximum="$PACKET_LOSS_THRESHOLD_PERCENT" \
           'BEGIN { exit !(actual > maximum) }'; then
        reasons+=("packet loss above ${PACKET_LOSS_THRESHOLD_PERCENT}%")
    fi

    if [[ "${#reasons[@]}" -eq 0 ]]; then
        STATUS="healthy"
        REASON="within configured thresholds"
    else
        STATUS="degraded"
        printf -v REASON '%s; ' "${reasons[@]}"
        REASON="${REASON%; }"
    fi

    calculate_health_score
}

format_metric() {
    local value="$1"
    local decimals="$2"
    local unavailable_text="$3"

    if awk -v value="$value" 'BEGIN { exit !(value < 0) }'; then
        printf '%s' "$unavailable_text"
    else
        awk -v value="$value" -v decimals="$decimals" \
            'BEGIN { printf "%.*f", decimals, value }'
    fi
}

validate_configuration
mkdir -p "$BASE/logs" "$BASE/state"

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    echo "A speed test is already running."
    exit 0
fi

rotate_speed_log
prepare_speed_log

PREVIOUS_STATE="$(cat "$STATE_FILE" 2>/dev/null || echo unknown)"
ATTEMPT=1
STATUS="error"
REASON="Speed test failed"
TEST_ERROR=""
DOWNLOAD_MBPS="-1.00"
UPLOAD_MBPS="-1.00"
LATENCY_MS="-1.00"
PACKET_LOSS_PERCENT="-1.00"
SERVER="Unknown server"
ISP="Unknown ISP"
PACKET_LOSS_SOURCE="unavailable"
HEALTH_SCORE="-1"
FIRST_ATTEMPT_REASON=""

while [[ "$ATTEMPT" -le "$SPEEDTEST_MAX_ATTEMPTS" ]]; do
    if run_speed_test; then
        evaluate_result
    else
        STATUS="error"
        REASON="$TEST_ERROR"
    fi

    if [[ "$STATUS" == "healthy" ]]; then
        break
    fi

    if [[ "$ATTEMPT" -eq 1 ]]; then
        FIRST_ATTEMPT_REASON="${STATUS} on ${SERVER}: ${REASON}"
    fi

    if [[ "$ATTEMPT" -ge "$SPEEDTEST_MAX_ATTEMPTS" ]]; then
        break
    fi

    sleep "$SPEEDTEST_RETRY_DELAY_SECONDS"
    ATTEMPT=$((ATTEMPT + 1))
done

if [[ "$ATTEMPT" -gt 1 && -n "$FIRST_ATTEMPT_REASON" ]]; then
    if [[ "$STATUS" == "healthy" ]]; then
        REASON="within configured thresholds after retry; initial result ${FIRST_ATTEMPT_REASON}"
    else
        REASON="${REASON}; initial result ${FIRST_ATTEMPT_REASON}"
    fi
fi

if [[ "$STATUS" != "error" ]]; then
    resolve_isp "$ISP"
fi

NOW="$(date '+%Y-%m-%d %H:%M:%S')"
DISPLAY_TIME="$(date '+%H:%M')"
SERVER_DISPLAY="${SERVER% Limited}"
ISP="$(sanitize_csv_text "$ISP")"
ISP="${ISP% Limited}"
REASON="$(sanitize_csv_text "$REASON")"
HEALTH_LABEL="$(health_label "$HEALTH_SCORE")"

printf '"%s",%s,%s,%s,%s,"%s",%s,"%s","%s",%s,%s,"%s"\n' \
    "$NOW" \
    "$DOWNLOAD_MBPS" \
    "$UPLOAD_MBPS" \
    "$LATENCY_MS" \
    "$PACKET_LOSS_PERCENT" \
    "$PACKET_LOSS_SOURCE" \
    "$HEALTH_SCORE" \
    "$ISP" \
    "$SERVER" \
    "$STATUS" \
    "$ATTEMPT" \
    "$REASON" \
    >> "$LOG_FILE"

DOWNLOAD_DISPLAY="$(format_metric "$DOWNLOAD_MBPS" 0 "N/A")"
UPLOAD_DISPLAY="$(format_metric "$UPLOAD_MBPS" 0 "N/A")"
LATENCY_DISPLAY="$(format_metric "$LATENCY_MS" 0 "N/A")"
PACKET_LOSS_DISPLAY="$(format_metric "$PACKET_LOSS_PERCENT" 2 "N/A")"
if [[ "$PACKET_LOSS_DISPLAY" == "N/A" ]]; then
    PACKET_LOSS_TEXT="N/A"
else
    PACKET_LOSS_TEXT="${PACKET_LOSS_DISPLAY}%"
fi

case "$STATUS" in
degraded)
    printf '%s\n' "degraded" > "$STATE_FILE"

    if [[ "$PREVIOUS_STATE" != "degraded" ]]; then
        send_telegram "📊 Home Network Status

🟠 Performance Degraded

⬇️ Download: ${DOWNLOAD_DISPLAY} Mbps
⬆️ Upload: ${UPLOAD_DISPLAY} Mbps
📶 Latency: ${LATENCY_DISPLAY} ms
📦 Packet loss: ${PACKET_LOSS_TEXT}
❤️ Health score: ${HEALTH_SCORE}/100 (${HEALTH_LABEL})
🏢 ISP: ${ISP}
🌐 Server: ${SERVER_DISPLAY}

⚠️ ${REASON}
🧪 Confirmed after ${ATTEMPT} test(s)
🕒 ${DISPLAY_TIME}"
    fi
    ;;

error)
    printf '%s\n' "error" > "$STATE_FILE"

    if [[ "$PREVIOUS_STATE" != "error" ]]; then
        send_telegram "⚠️ Home Network Speed Test Failed

${REASON}

🧪 Attempts: ${ATTEMPT}
🕒 ${DISPLAY_TIME}"
    fi
    ;;

healthy)
    printf '%s\n' "healthy" > "$STATE_FILE"

    if [[ "$PREVIOUS_STATE" =~ ^(degraded|error)$ ]] && \
       [[ "$RECOVERY_NOTIFICATIONS" == "true" ]]; then
        send_telegram "📊 Home Network Status

🟢 Performance Restored

⬇️ Download: ${DOWNLOAD_DISPLAY} Mbps
⬆️ Upload: ${UPLOAD_DISPLAY} Mbps
📶 Latency: ${LATENCY_DISPLAY} ms
📦 Packet loss: ${PACKET_LOSS_TEXT}
❤️ Health score: ${HEALTH_SCORE}/100 (${HEALTH_LABEL})
🏢 ISP: ${ISP}
🌐 Server: ${SERVER_DISPLAY}

🕒 ${DISPLAY_TIME}"

    elif [[ "$NOTIFY_ON_SUCCESS" == "true" ]]; then
        send_telegram "📊 Home Network Status

🟢 Healthy

⬇️ Download: ${DOWNLOAD_DISPLAY} Mbps
⬆️ Upload: ${UPLOAD_DISPLAY} Mbps
📶 Latency: ${LATENCY_DISPLAY} ms
📦 Packet loss: ${PACKET_LOSS_TEXT}
❤️ Health score: ${HEALTH_SCORE}/100 (${HEALTH_LABEL})
🏢 ISP: ${ISP}
🌐 Server: ${SERVER_DISPLAY}

🕒 ${DISPLAY_TIME}"
    fi
    ;;
esac
