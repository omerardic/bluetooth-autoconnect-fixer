#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${RED}=== Bluetooth Auto-Connect Uninstaller ===${NC}"

SYSTEMD_FILE="$HOME/.config/systemd/user/bluetooth-autoconnect.service"
SCRIPT_FILE="$HOME/.local/bin/bluetooth_monitor.py"
CONFIG_FILE="$HOME/.config/bluetooth_autoconnect.conf"

# 1. Stop and Disable Service
if systemctl --user is-active --quiet bluetooth-autoconnect.service; then
    echo "Stopping service..."
    systemctl --user stop bluetooth-autoconnect.service
fi

if systemctl --user is-enabled --quiet bluetooth-autoconnect.service; then
    echo "Disabling service..."
    systemctl --user disable bluetooth-autoconnect.service
fi

# 2. Remove Files
echo "Removing files..."

if [ -f "$SYSTEMD_FILE" ]; then
    rm "$SYSTEMD_FILE"
    echo "Removed service file."
fi

if [ -f "$SCRIPT_FILE" ]; then
    rm "$SCRIPT_FILE"
    echo "Removed script file."
fi

if [ -f "$CONFIG_FILE" ]; then
    rm "$CONFIG_FILE"
    echo "Removed configuration file."
fi

# 3. Reload Systemd
systemctl --user daemon-reload

echo -e "\n${GREEN}Uninstallation complete.${NC}"

