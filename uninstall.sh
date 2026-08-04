#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR="/opt/home-network-monitor"
CLI_PATH="/usr/local/bin/network-monitor"
CRON_MARKER="HOME-NETWORK-MONITOR"

echo "Removing Home Network Monitor..."

CURRENT_CRON="$(crontab -l 2>/dev/null || true)"

printf '%s\n' "$CURRENT_CRON" |
    grep -v "$CRON_MARKER" |
    crontab - 2>/dev/null || true

sudo rm -f "$CLI_PATH"

read -r -p "Keep configuration and logs? [Y/n]: " answer
answer="${answer:-Y}"

if [[ "$answer" =~ ^[Nn]$ ]]; then
    sudo rm -rf "$INSTALL_DIR"
    echo "Configuration, logs and state removed."
else
    sudo rm -f \
        "$INSTALL_DIR/internet-monitor.sh" \
        "$INSTALL_DIR/speed-monitor.sh"

    echo "Configuration, logs and state preserved in:"
    echo "$INSTALL_DIR"
fi

echo "Uninstallation complete."
