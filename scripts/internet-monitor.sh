#!/usr/bin/env bash

set -u
set -o pipefail

BASE="${HOME_NETWORK_MONITOR_BASE:-/opt/home-network-monitor}"
CONFIG_FILE="$BASE/config.conf"
STATE_FILE="$BASE/state/internet.state"
TARGET_STATE_FILE="$BASE/state/internet.target"
OUTAGE_START_FILE="$BASE/state/outage-start"
LOG_FILE="$BASE/logs/internet.log"

if [[ ! -r "$CONFIG_FILE" ]]; then
    echo "Configuration file is missing or unreadable: $CONFIG_FILE" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

CONNECTIVITY_TARGETS="${CONNECTIVITY_TARGETS:-8.8.8.8 1.1.1.1}"
CONNECTIVITY_PING_COUNT="${CONNECTIVITY_PING_COUNT:-2}"
CONNECTIVITY_PING_TIMEOUT_SECONDS="${CONNECTIVITY_PING_TIMEOUT_SECONDS:-3}"
LOG_MAX_SIZE_BYTES="${LOG_MAX_SIZE_BYTES:-1048576}"
LOG_RETENTION_DAYS="${LOG_RETENTION_DAYS:-90}"

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

validate_configuration() {
    if [[ -z "$CONNECTIVITY_TARGETS" ]]; then
        echo "CONNECTIVITY_TARGETS must contain at least one target." >&2
        exit 1
    fi

    if [[ ! "$CONNECTIVITY_PING_COUNT" =~ ^[1-9][0-9]*$ ]] || \
       [[ ! "$CONNECTIVITY_PING_TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]]; then
        echo "Connectivity ping count and timeout must be positive integers." >&2
        exit 1
    fi

    if [[ ! "$LOG_MAX_SIZE_BYTES" =~ ^[1-9][0-9]*$ ]] || \
       [[ ! "$LOG_RETENTION_DAYS" =~ ^[1-9][0-9]*$ ]]; then
        echo "Log size and retention settings must be positive integers." >&2
        exit 1
    fi
}

rotate_internet_log() {
    local size=0
    local archive_file=""

    if [[ -f "$LOG_FILE" ]]; then
        size="$(wc -c < "$LOG_FILE")"
    fi

    if [[ "$size" -ge "$LOG_MAX_SIZE_BYTES" ]]; then
        archive_file="$BASE/logs/internet-$(date '+%Y%m%d-%H%M%S').log"
        mv "$LOG_FILE" "$archive_file"
    fi

    find "$BASE/logs" \
        -maxdepth 1 \
        -type f \
        -name 'internet-*.log' \
        -mtime "+$LOG_RETENTION_DAYS" \
        -delete 2>/dev/null || true
}

format_duration() {
    local total_seconds="$1"

    if [[ "$total_seconds" -lt 60 ]]; then
        printf '%s second(s)' "$total_seconds"
    else
        printf '%s minute(s)' "$((total_seconds / 60))"
    fi
}

validate_configuration
mkdir -p "$BASE/logs" "$BASE/state"
rotate_internet_log

NOW="$(date '+%Y-%m-%d %H:%M:%S')"
NOW_EPOCH="$(date +%s)"
CURRENT_STATE="down"
WORKING_TARGET="none"

for target in $CONNECTIVITY_TARGETS; do
    if ping \
        -c "$CONNECTIVITY_PING_COUNT" \
        -W "$CONNECTIVITY_PING_TIMEOUT_SECONDS" \
        "$target" >/dev/null 2>&1; then
        CURRENT_STATE="up"
        WORKING_TARGET="$target"
        break
    fi
done

PREVIOUS_STATE="$(cat "$STATE_FILE" 2>/dev/null || echo unknown)"
printf '%s\n' "$CURRENT_STATE" > "$STATE_FILE"
printf '%s\n' "$WORKING_TARGET" > "$TARGET_STATE_FILE"
printf '%s,%s\n' "$NOW" "${CURRENT_STATE^^}" >> "$LOG_FILE"

if [[ "$CURRENT_STATE" == "down" && "$PREVIOUS_STATE" != "down" ]]; then
    printf '%s\n' "$NOW_EPOCH" > "$OUTAGE_START_FILE"

elif [[ "$CURRENT_STATE" == "up" && "$PREVIOUS_STATE" == "down" ]]; then
    OUTAGE_STARTED="$(cat "$OUTAGE_START_FILE" 2>/dev/null || echo "$NOW_EPOCH")"

    if [[ ! "$OUTAGE_STARTED" =~ ^[0-9]+$ ]]; then
        OUTAGE_STARTED="$NOW_EPOCH"
    fi

    DURATION_SECONDS=$((NOW_EPOCH - OUTAGE_STARTED))
    DURATION_TEXT="$(format_duration "$DURATION_SECONDS")"

    send_telegram "🟢 Home internet restored

Approximate downtime: ${DURATION_TEXT}
Connectivity target: ${WORKING_TARGET}
Restored: ${NOW}"

    rm -f "$OUTAGE_START_FILE"
fi
