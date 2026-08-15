#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
BASE="$TEST_ROOT/base"
BIN="$TEST_ROOT/bin"

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

mkdir -p "$BASE/logs" "$BASE/state" "$BIN"
install -m 0755 "$PROJECT_DIR/scripts/speed-monitor.sh" "$BASE/speed-monitor.sh"
install -m 0755 "$PROJECT_DIR/scripts/daily-summary.sh" "$BASE/daily-summary.sh"
install -m 0755 "$PROJECT_DIR/scripts/internet-monitor.sh" "$BASE/internet-monitor.sh"
install -m 0755 "$PROJECT_DIR/scripts/network-monitor" "$BIN/network-monitor"
install -m 0755 "$PROJECT_DIR/tests/fake-speedtest-go" "$BIN/speedtest-go"
install -m 0755 "$PROJECT_DIR/tests/curl" "$BIN/curl"
install -m 0755 "$PROJECT_DIR/tests/ping" "$BIN/ping"
install -m 0644 "$PROJECT_DIR/VERSION" "$BASE/VERSION"

FAKE_COUNT_FILE="$TEST_ROOT/count"
FAKE_CURL_LOG="$TEST_ROOT/curl.log"
export FAKE_COUNT_FILE FAKE_CURL_LOG
export HOME_NETWORK_MONITOR_BASE="$BASE"
export PATH="$BIN:$PATH"

printf '%s\n' 'BOT_TOKEN="test-token"' > "$BASE/config.conf"
printf '%s\n' 'CHAT_ID="test-chat"' >> "$BASE/config.conf"
printf '%s\n' 'DOWNLOAD_THRESHOLD_MBPS="600"' >> "$BASE/config.conf"
printf '%s\n' 'UPLOAD_THRESHOLD_MBPS="600"' >> "$BASE/config.conf"
printf '%s\n' 'LATENCY_THRESHOLD_MS="30"' >> "$BASE/config.conf"
printf '%s\n' 'PACKET_LOSS_THRESHOLD_PERCENT="2"' >> "$BASE/config.conf"
printf '%s\n' 'PACKET_LOSS_HOST="8.8.8.8"' >> "$BASE/config.conf"
printf '%s\n' 'PACKET_LOSS_PING_COUNT="20"' >> "$BASE/config.conf"
printf '%s\n' 'PACKET_LOSS_PING_INTERVAL_SECONDS="0.2"' >> "$BASE/config.conf"
printf '%s\n' 'PACKET_LOSS_PING_TIMEOUT_SECONDS="1"' >> "$BASE/config.conf"
printf '%s\n' 'CONNECTIVITY_TARGETS="8.8.8.8 1.1.1.1"' >> "$BASE/config.conf"
printf '%s\n' 'CONNECTIVITY_PING_COUNT="2"' >> "$BASE/config.conf"
printf '%s\n' 'CONNECTIVITY_PING_TIMEOUT_SECONDS="3"' >> "$BASE/config.conf"
printf '%s\n' "SPEEDTEST_BINARY=\"$BIN/speedtest-go\"" >> "$BASE/config.conf"
printf '%s\n' 'SPEEDTEST_SERVER_ID="30690"' >> "$BASE/config.conf"
printf '%s\n' 'SPEEDTEST_FALLBACK_SERVER_ID="54208"' >> "$BASE/config.conf"
printf '%s\n' 'SPEEDTEST_MAX_ATTEMPTS="2"' >> "$BASE/config.conf"
printf '%s\n' 'SPEEDTEST_RETRY_DELAY_SECONDS="0"' >> "$BASE/config.conf"
printf '%s\n' 'ISP_NAME_OVERRIDE=""' >> "$BASE/config.conf"
printf '%s\n' 'ISP_LOOKUP_ENABLED="true"' >> "$BASE/config.conf"
printf '%s\n' 'ISP_LOOKUP_URL="https://ipinfo.io/org"' >> "$BASE/config.conf"
printf '%s\n' 'ISP_LOOKUP_TIMEOUT_SECONDS="10"' >> "$BASE/config.conf"
printf '%s\n' 'NOTIFY_ON_SUCCESS="false"' >> "$BASE/config.conf"
printf '%s\n' 'RECOVERY_NOTIFICATIONS="true"' >> "$BASE/config.conf"
printf '%s\n' 'LOG_MAX_SIZE_BYTES="1048576"' >> "$BASE/config.conf"
printf '%s\n' 'LOG_RETENTION_DAYS="90"' >> "$BASE/config.conf"

printf '%s\n' 'timestamp,download_mbps,latency_ms,server,status' > "$BASE/logs/speed.csv"
printf '%s\n' '"2026-08-15 08:00:01",832.66,5.16,"Community Fibre Limited",healthy' >> "$BASE/logs/speed.csv"

export FAKE_MODE="healthy"
export FAKE_PACKET_LOSS_PERCENT="0"
: > "$FAKE_COUNT_FILE"
: > "$FAKE_CURL_LOG"
"$BASE/speed-monitor.sh"

test "$(cat "$BASE/state/speed.state")" = "healthy"
grep -q '^timestamp,download_mbps,upload_mbps,latency_ms,packet_loss_percent,packet_loss_source,health_score,isp' "$BASE/logs/speed.csv"
find "$BASE/logs" -name 'speed-legacy-*.csv' -print -quit | grep -q .
tail -n 1 "$BASE/logs/speed.csv" | grep -q ',healthy,1,'
tail -n 1 "$BASE/logs/speed.csv" | grep -q '"ping:8.8.8.8",100,"Independent Test ISP"'
test ! -s "$FAKE_CURL_LOG"

printf '%s\n' 'ISP_NAME_OVERRIDE="Configured ISP"' >> "$BASE/config.conf"
: > "$FAKE_COUNT_FILE"
"$BASE/speed-monitor.sh"
tail -n 1 "$BASE/logs/speed.csv" | grep -q ',100,"Configured ISP"'

printf '%s\n' 'ISP_NAME_OVERRIDE=""' >> "$BASE/config.conf"
export FAKE_ISP_LOOKUP_FAIL="true"
: > "$FAKE_COUNT_FILE"
"$BASE/speed-monitor.sh"
tail -n 1 "$BASE/logs/speed.csv" | grep -q ',100,"Test ISP"'
export FAKE_ISP_LOOKUP_FAIL="false"

export FAKE_MODE="degraded"
: > "$FAKE_COUNT_FILE"
: > "$FAKE_CURL_LOG"
"$BASE/speed-monitor.sh"

test "$(cat "$BASE/state/speed.state")" = "degraded"
tail -n 1 "$BASE/logs/speed.csv" | grep -q ',degraded,2,'
grep -q 'Performance Degraded' "$FAKE_CURL_LOG"
grep -q 'upload below 600 Mbps' "$FAKE_CURL_LOG"

export FAKE_MODE="healthy"
: > "$FAKE_COUNT_FILE"
: > "$FAKE_CURL_LOG"
"$BASE/speed-monitor.sh"

test "$(cat "$BASE/state/speed.state")" = "healthy"
grep -q 'Performance Restored' "$FAKE_CURL_LOG"

export FAKE_MODE="degraded_then_healthy"
: > "$FAKE_COUNT_FILE"
: > "$FAKE_CURL_LOG"
"$BASE/speed-monitor.sh"

test "$(cat "$BASE/state/speed.state")" = "healthy"
tail -n 1 "$BASE/logs/speed.csv" | grep -q ',healthy,2,'
test ! -s "$FAKE_CURL_LOG"

export FAKE_MODE="packet_loss"
export FAKE_PACKET_LOSS_PERCENT="0"
: > "$FAKE_COUNT_FILE"
: > "$FAKE_CURL_LOG"
"$BASE/speed-monitor.sh"

test "$(cat "$BASE/state/speed.state")" = "degraded"
tail -n 1 "$BASE/logs/speed.csv" | grep -q ',5.00,'
grep -q 'packet loss above 2%' "$FAKE_CURL_LOG"

export FAKE_MODE="healthy"
export FAKE_PACKET_LOSS_PERCENT="5"
: > "$FAKE_COUNT_FILE"
: > "$FAKE_CURL_LOG"
printf '%s\n' "healthy" > "$BASE/state/speed.state"
"$BASE/speed-monitor.sh"
test "$(cat "$BASE/state/speed.state")" = "degraded"
grep -q 'packet loss above 2%' "$FAKE_CURL_LOG"

export FAKE_PACKET_LOSS_PERCENT="0"

today="$(date '+%Y-%m-%d')"
printf '%s\n' "$today 08:00:00,UP" > "$BASE/logs/internet.log"
printf '%s\n' "$today 08:05:00,UP" >> "$BASE/logs/internet.log"
printf '%s\n' "$today 08:10:00,DOWN" >> "$BASE/logs/internet.log"
: > "$FAKE_CURL_LOG"
"$BASE/daily-summary.sh"
grep -q 'Average upload' "$FAKE_CURL_LOG"
grep -q 'Average health score' "$FAKE_CURL_LOG"
grep -q 'ISP: Independent Test ISP' "$FAKE_CURL_LOG"
grep -q "Today's uptime: 66.67%" "$FAKE_CURL_LOG"

STATUS_OUTPUT="$("$BIN/network-monitor" status)"
grep -q 'Upload' <<< "$STATUS_OUTPUT"
grep -q 'Packet loss' <<< "$STATUS_OUTPUT"
grep -q 'Health score' <<< "$STATUS_OUTPUT"
grep -q 'ISP' <<< "$STATUS_OUTPUT"
test "$("$BIN/network-monitor" version)" = "Home Network Monitor v1.3.0"

export FAKE_CONNECTIVITY_DOWN="false"
: > "$FAKE_CURL_LOG"
"$BASE/internet-monitor.sh"
test "$(cat "$BASE/state/internet.state")" = "up"
test "$(cat "$BASE/state/internet.target")" = "8.8.8.8"

export FAKE_CONNECTIVITY_DOWN="true"
"$BASE/internet-monitor.sh"
test "$(cat "$BASE/state/internet.state")" = "down"
test -f "$BASE/state/outage-start"

export FAKE_CONNECTIVITY_DOWN="false"
"$BASE/internet-monitor.sh"
test "$(cat "$BASE/state/internet.state")" = "up"
grep -q 'Home internet restored' "$FAKE_CURL_LOG"

printf '%s\n' 'LOG_MAX_SIZE_BYTES="1"' >> "$BASE/config.conf"
"$BASE/internet-monitor.sh"
find "$BASE/logs" -name 'internet-*.log' -print -quit | grep -q .

echo "All v1.3 tests passed."
