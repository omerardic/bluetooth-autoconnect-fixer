#!/bin/bash

# Colors for better UX
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

CONFIG_DIR="$HOME/.config"
CONFIG_FILE="$CONFIG_DIR/bluetooth_autoconnect.conf"
INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="bluetooth_monitor.py"
SYSTEMD_DIR="$HOME/.config/systemd/user"
SERVICE_NAME="bluetooth-autoconnect.service"

# --- Helper: Python Config Manager ---
# We use a tiny embedded python script to handle INI file operations safely.
manage_config() {
    python3 -c "
import configparser
import sys
import os

action = sys.argv[1]
file_path = '$CONFIG_FILE'

# Fix: Only allow '=' as delimiter so MAC addresses with ':' are treated as keys
config = configparser.ConfigParser(delimiters=('=',))
config.optionxform = str # Preserve case sensitivity of keys (MAC addresses)

if os.path.exists(file_path):
    config.read(file_path)

if 'Devices' not in config:
    config['Devices'] = {}

if action == 'add':
    mac = sys.argv[2]
    name = sys.argv[3]
    config['Devices'][mac] = name
    print(f'Added {name} ({mac})')

elif action == 'remove':
    mac = sys.argv[2]
    if mac in config['Devices']:
        del config['Devices'][mac]
        print(f'Removed {mac}')
    else:
        print('Device not found in config')

elif action == 'list':
    for mac, name in config['Devices'].items():
        print(f'{mac}|{name}')

with open(file_path, 'w') as configfile:
    config.write(configfile)
" "$@"
}

# --- Functions ---

check_dependencies() {
    if ! command -v python3 &> /dev/null;
        then
        echo -e "${RED}Error: python3 is not installed.${NC}"
        exit 1
    fi
    if ! command -v bluetoothctl &> /dev/null;
        then
        echo -e "${RED}Error: bluetoothctl (BlueZ) is not installed.${NC}"
        exit 1
    fi
}

install_service() {
    echo -e "\n${BLUE}--- Installing/Updating Service ---${NC}"
    
    # 1. Install Script
    mkdir -p "$INSTALL_DIR"
    cp "src/$SCRIPT_NAME" "$INSTALL_DIR/$SCRIPT_NAME"
    chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
    echo -e "Script installed to $INSTALL_DIR/$SCRIPT_NAME"

    # 2. Create Service File
    mkdir -p "$SYSTEMD_DIR"
    cat > "$SYSTEMD_DIR/$SERVICE_NAME" <<EOF
[Unit]
Description=Bluetooth Auto-Connect Monitor
After=bluetooth.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 "$INSTALL_DIR/$SCRIPT_NAME"
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF
    echo -e "Service file created."

    # 3. Reload and Start
    systemctl --user daemon-reload
    systemctl --user enable "$SERVICE_NAME"
    systemctl --user restart "$SERVICE_NAME"
    
    echo -e "${GREEN}✔ Service installed and restarted.${NC}"
}

uninstall_service() {
    echo -e "\n${RED}--- Uninstalling Service ---${NC}"

    SYSTEMD_FILE="$SYSTEMD_DIR/$SERVICE_NAME"
    SCRIPT_FILE="$INSTALL_DIR/$SCRIPT_NAME"

    # 1. Stop and Disable Service
    if systemctl --user list-unit-files "$SERVICE_NAME" | grep -q "$SERVICE_NAME"; then
        echo "Stopping and disabling service..."
        systemctl --user stop "$SERVICE_NAME" 2>/dev/null
        systemctl --user disable "$SERVICE_NAME" 2>/dev/null
    else
        echo "Service not running or not installed."
    fi

    # 2. Remove Files
    echo -e "\nRemoving files..."

    if [ -f "$SYSTEMD_FILE" ]; then
        rm "$SYSTEMD_FILE"
        echo -e "${GREEN}✔ Removed service file.${NC}"
    else
        echo -e "${YELLOW}Service file not found (already removed?)${NC}"
    fi

    if [ -f "$SCRIPT_FILE" ]; then
        rm "$SCRIPT_FILE"
        echo -e "${GREEN}✔ Removed script file.${NC}"
    else
        echo -e "${YELLOW}Script file not found (already removed?)${NC}"
    fi

    if [ -f "$CONFIG_FILE" ]; then
        rm "$CONFIG_FILE"
        echo -e "${GREEN}✔ Removed configuration file.${NC}"
    else
        echo -e "${YELLOW}Configuration file not found (already removed?)${NC}"
    fi

    # 3. Reload Systemd
    systemctl --user daemon-reload

    # 4. Final Verification
    echo -e "\nVerifying cleanup..."
    if systemctl --user is-active --quiet "$SERVICE_NAME"; then
        echo -e "${RED}✘ Warning: Service is still active!${NC}"
    elif systemctl --user list-unit-files "$SERVICE_NAME" | grep -q "$SERVICE_NAME"; then
        echo -e "${RED}✘ Warning: Service unit file still exists in systemd.${NC}"
    else
        echo -e "${GREEN}✔ Cleanup verified: Service is removed.${NC}"
    fi
}

add_device() {
    echo -e "\n${BLUE}--- Add New Device ---${NC}"
    echo "Scanning for paired Bluetooth devices..."
    
    mapfile -t DEVICES < <(bluetoothctl devices)
    
    if [ ${#DEVICES[@]} -eq 0 ]; then
        echo -e "${YELLOW}No paired devices found.${NC}"
        return
    fi

    echo -e "${GREEN}Available Devices:${NC}"
    i=1
    for device in "${DEVICES[@]}"; do
        mac=$(echo "$device" | cut -d ' ' -f 2)
        name=$(echo "$device" | cut -d ' ' -f 3-)
        echo "[$i] $name ($mac)"
        ((i++))
    done
    echo "[0] Cancel"

    echo -n "Select a device number: "
    read -r choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -eq 0 ] || [ "$choice" -gt "${#DEVICES[@]}" ]; then
        echo "Cancelled."
        return
    fi

    selected="${DEVICES[$((choice-1))]}"
    mac=$(echo "$selected" | cut -d ' ' -f 2)
    name=$(echo "$selected" | cut -d ' ' -f 3-)

    # Add to config
    mkdir -p "$CONFIG_DIR"
    manage_config "add" "$mac" "$name"
    
    echo -e "${GREEN}Device added!${NC}"
    
    # Check if service is installed before restarting
    if systemctl --user list-unit-files "$SERVICE_NAME" | grep -q "$SERVICE_NAME"; then
        echo "Restarting service to apply changes..."
        systemctl --user restart "$SERVICE_NAME"
    else
        echo -e "${YELLOW}You have added a device to be monitored but the monitoring service is not installed.${NC}"
        echo -n "Should I install the monitoring service now? (y/n): "
        read -r install_choice
        if [[ "$install_choice" =~ ^[Yy]$ ]]; then
            install_service
        else
            echo "Returning to main menu."
        fi
    fi
}

remove_device() {
    echo -e "\n${BLUE}--- Remove Device ---${NC}"
    
    # Get list from python helper
    # Output format: MAC|Name
    current_devices=$(manage_config "list")
    
    if [ -z "$current_devices" ]; then
        echo "No configured devices found."
        return
    fi

    IFS=$'\n' read -rd '' -a DEVICE_LIST <<< "$current_devices"
    
    echo -e "${GREEN}Monitored Devices:${NC}"
    i=1
    for item in "${DEVICE_LIST[@]}"; do
        IFS='|' read -r mac name <<< "$item"
        echo "[$i] $name ($mac)"
        ((i++))
    done
    echo "[0] Cancel"

    echo -n "Select a number to remove: "
    read -r choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -eq 0 ] || [ "$choice" -gt "${#DEVICE_LIST[@]}" ]; then
        echo "Cancelled."
        return
    fi

    item="${DEVICE_LIST[$((choice-1))]}"
    IFS='|' read -r mac name <<< "$item"
    
    manage_config "remove" "$mac"
    
    echo -e "${GREEN}Device removed!${NC}"
    
    # Check if service is installed before restarting
    if systemctl --user list-unit-files "$SERVICE_NAME" | grep -q "$SERVICE_NAME"; then
        echo "Restarting service..."
        systemctl --user restart "$SERVICE_NAME"
    else
        echo -e "${YELLOW}Service not installed yet. Please run 'Option 1: Install Bluetooth Device Auto-Connect Service'.${NC}"
    fi
}

# --- Main Menu ---

check_dependencies

while true; do
    echo -e "\n${BLUE}=== Bluetooth Device Auto-Connect Manager ===${NC}"
    echo "1) Install Bluetooth Device Auto-Connect Service"
    echo "2) Add a new device to monitor"
    echo "3) Remove a device from monitored list"
    echo "4) Uninstall Service"
    echo "5) Quit"
    echo -n "Choose an option: "
    read -r opt

    case $opt in
        1) install_service ;;
        2) add_device ;;
        3) remove_device ;;
        4) uninstall_service ;;
        5) echo "Bye!"; exit 0 ;;
        *) echo "Invalid option." ;;
    esac
done
