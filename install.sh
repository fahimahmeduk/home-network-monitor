#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/opt/home-network-monitor"
CLI_PATH="/usr/local/bin/network-monitor"
CONFIG_FILE="$INSTALL_DIR/config.conf"
CRON_MARKER="HOME-NETWORK-MONITOR"

echo "Installing Home Network Monitor..."

for command in curl jq ping awk timeout crontab; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Missing dependency: $command"
        echo "Install the required dependency and run the installer again."
        exit 1
    fi
done

if ! command -v speedtest-go >/dev/null 2>&1; then
    echo "Missing dependency: speedtest-go"
    echo "Install speedtest-go in /usr/local/bin before continuing."
    exit 1
fi

sudo mkdir -p "$INSTALL_DIR/logs" "$INSTALL_DIR/state"

sudo install -m 0755 \
    "$PROJECT_DIR/scripts/internet-monitor.sh" \
    "$INSTALL_DIR/internet-monitor.sh"

sudo install -m 0755 \
    "$PROJECT_DIR/scripts/speed-monitor.sh" \
    "$INSTALL_DIR/speed-monitor.sh"

sudo install -m 0755 \
    "$PROJECT_DIR/scripts/network-monitor" \
    "$CLI_PATH"

if [[ ! -f "$CONFIG_FILE" ]]; then
    sudo install -m 0600 \
        "$PROJECT_DIR/config/config.example.conf" \
        "$CONFIG_FILE"

    echo
    echo "A new configuration file was created:"
    echo "$CONFIG_FILE"
    echo
    echo "Edit it and add your Telegram bot token and chat ID:"
    echo "sudo nano $CONFIG_FILE"
else
    echo "Existing configuration preserved:"
    echo "$CONFIG_FILE"
fi

CURRENT_CRON="$(crontab -l 2>/dev/null || true)"

{
    printf '%s\n' "$CURRENT_CRON" |
        grep -v "$CRON_MARKER" || true

    echo "*/5 * * * * $INSTALL_DIR/internet-monitor.sh >/dev/null 2>&1 # $CRON_MARKER"
    echo "0 8,20 * * * $INSTALL_DIR/speed-monitor.sh >/dev/null 2>&1 # $CRON_MARKER"
} | crontab -

echo
echo "Installation complete."
echo
echo "Connectivity checks: every 5 minutes"
echo "Speed tests: 08:00 and 20:00"
echo
echo "Next steps:"
echo "1. Review $CONFIG_FILE"
echo "2. Run: network-monitor test-telegram"
echo "3. Run: network-monitor check"
echo "4. Run: network-monitor status"
