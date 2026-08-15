#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/opt/home-network-monitor"
CLI_PATH="/usr/local/bin/network-monitor"
CONFIG_FILE="$INSTALL_DIR/config.conf"
CRON_MARKER="HOME-NETWORK-MONITOR"
INSTALL_USER="$(id -un)"
INSTALL_GROUP="$(id -gn)"
SPEEDTEST_PATH="$(command -v speedtest-go 2>/dev/null || true)"

echo "Installing Home Network Monitor..."

for command in curl jq ping awk timeout crontab flock; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Missing dependency: $command"
        echo "Install the required dependency and run the installer again."
        exit 1
    fi
done

if [[ -z "$SPEEDTEST_PATH" ]]; then
    echo "Missing dependency: speedtest-go"
    echo "Install speedtest-go before continuing."
    exit 1
fi

sudo mkdir -p "$INSTALL_DIR/logs" "$INSTALL_DIR/state"
sudo chown -R "$INSTALL_USER:$INSTALL_GROUP" \
    "$INSTALL_DIR/logs" \
    "$INSTALL_DIR/state"

sudo install -m 0755 \
    "$PROJECT_DIR/scripts/internet-monitor.sh" \
    "$INSTALL_DIR/internet-monitor.sh"

sudo install -m 0755 \
    "$PROJECT_DIR/scripts/speed-monitor.sh" \
    "$INSTALL_DIR/speed-monitor.sh"

sudo install -m 0755 \
    "$PROJECT_DIR/scripts/daily-summary.sh" \
    "$INSTALL_DIR/daily-summary.sh"

sudo install -m 0755 \
    "$PROJECT_DIR/scripts/network-monitor" \
    "$CLI_PATH"

sudo install -m 0644 \
    "$PROJECT_DIR/VERSION" \
    "$INSTALL_DIR/VERSION"

if [[ ! -f "$CONFIG_FILE" ]]; then
    sudo install -m 0600 \
        -o "$INSTALL_USER" \
        -g "$INSTALL_GROUP" \
        "$PROJECT_DIR/config/config.example.conf" \
        "$CONFIG_FILE"

    echo
    echo "A new configuration file was created:"
    echo "$CONFIG_FILE"
    echo
    echo "Edit it and add your Telegram bot token and chat ID:"
    echo "sudo nano $CONFIG_FILE"
else
    sudo chown "$INSTALL_USER:$INSTALL_GROUP" "$CONFIG_FILE"
    sudo chmod 0600 "$CONFIG_FILE"
    echo "Existing configuration preserved:"
    echo "$CONFIG_FILE"
fi

ensure_config_setting() {
    local key="$1"
    local value="$2"

    if ! grep -q "^${key}=" "$CONFIG_FILE"; then
        printf '%s="%s"\n' "$key" "$value" |
            sudo -u "$INSTALL_USER" tee -a "$CONFIG_FILE" >/dev/null
        echo "Added configuration setting: $key"
    fi
}

ensure_config_setting "UPLOAD_THRESHOLD_MBPS" "600"
ensure_config_setting "PACKET_LOSS_THRESHOLD_PERCENT" "2"
ensure_config_setting "PACKET_LOSS_HOST" "8.8.8.8"
ensure_config_setting "PACKET_LOSS_PING_COUNT" "20"
ensure_config_setting "PACKET_LOSS_PING_INTERVAL_SECONDS" "0.2"
ensure_config_setting "PACKET_LOSS_PING_TIMEOUT_SECONDS" "1"
ensure_config_setting "CONNECTIVITY_TARGETS" "8.8.8.8 1.1.1.1"
ensure_config_setting "CONNECTIVITY_PING_COUNT" "2"
ensure_config_setting "CONNECTIVITY_PING_TIMEOUT_SECONDS" "3"
ensure_config_setting "SPEEDTEST_FALLBACK_SERVER_ID" "54208"
ensure_config_setting "SPEEDTEST_BINARY" "$SPEEDTEST_PATH"
ensure_config_setting "SPEEDTEST_MAX_ATTEMPTS" "2"
ensure_config_setting "SPEEDTEST_RETRY_DELAY_SECONDS" "60"
ensure_config_setting "ISP_NAME_OVERRIDE" ""
ensure_config_setting "ISP_LOOKUP_ENABLED" "true"
ensure_config_setting "ISP_LOOKUP_URL" "https://ipinfo.io/org"
ensure_config_setting "ISP_LOOKUP_TIMEOUT_SECONDS" "10"
ensure_config_setting "LOG_MAX_SIZE_BYTES" "1048576"
ensure_config_setting "LOG_RETENTION_DAYS" "90"

CURRENT_CRON="$(crontab -l 2>/dev/null || true)"

{
    printf '%s\n' "$CURRENT_CRON" |
        grep -v "$CRON_MARKER" || true

    echo "*/5 * * * * $INSTALL_DIR/internet-monitor.sh >/dev/null 2>&1 # $CRON_MARKER"
    echo "0 8,20 * * * $INSTALL_DIR/speed-monitor.sh >/dev/null 2>&1 # $CRON_MARKER"
    echo "10 20 * * * $INSTALL_DIR/daily-summary.sh >/dev/null 2>&1 # $CRON_MARKER"
} | crontab -

echo
echo "Installation complete."
echo
echo "Connectivity checks: every 5 minutes"
echo "Speed tests: 08:00 and 20:00"
echo "Daily summary: 20:10"
echo
echo "v1.3 safeguards:"
echo "- Upload and packet-loss monitoring"
echo "- Same-run confirmation of poor results"
echo "- Network Health Score and ISP reporting"
echo "- Independent ISP lookup with override and Speedtest fallback"
echo "- Automatic log rotation and retention"
echo "- Previous v1.2 speed log archived on the next speed check"
echo
echo "Next steps:"
echo "1. Review $CONFIG_FILE"
echo "2. Run: network-monitor test-telegram"
echo "3. Run: network-monitor speed"
echo "4. Run: network-monitor status"
