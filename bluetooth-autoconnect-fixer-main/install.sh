#!/bin/bash

# Colors for better UX
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Bluetooth Auto-Connect Installer ===${NC}"

# Check for dependencies
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: python3 is not installed.${NC}"
    exit 1
fi

if ! command -v bluetoothctl &> /dev/null; then
    echo -e "${RED}Error: bluetoothctl (BlueZ) is not installed.${NC}"
    exit 1
fi

echo -e "Scanning for paired Bluetooth devices..."

# Get list of devices (MAC Name)
# We use a temporary file to store the list to read it safely into an array
mapfile -t DEVICES < <(bluetoothctl devices)

if [ ${#DEVICES[@]} -eq 0 ]; then
    echo -e "${YELLOW}No paired devices found.${NC}"
    echo "Please pair and connect your device manually first, then run this installer again."
    exit 1
fi

echo -e "\n${GREEN}Available Devices:${NC}"
i=1
for device in "${DEVICES[@]}"; do
    # format: Device MAC Name
    mac=$(echo "$device" | cut -d ' ' -f 2)
    name=$(echo "$device" | cut -d ' ' -f 3-)
    echo "[$i] $name ($mac)"
    ((i++))
done
echo "[0] My device is not on this list"

echo -e "\n${YELLOW}Please enter the number of the device you want to auto-connect to:${NC}"
read -r choice

# Validate input
if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Invalid input. Please enter a number.${NC}"
    exit 1
fi

if [ "$choice" -eq 0 ]; then
    echo -e "\n${BLUE}Guidance:${NC}"
    echo "1. Turn on your Bluetooth device."
    echo "2. Open your system's Bluetooth settings."
    echo "3. Pair and connect to your device."
    echo "4. Run this installer again."
    exit 0
fi

if [ "$choice" -gt "${#DEVICES[@]}" ] || [ "$choice" -lt 1 ]; then
    echo -e "${RED}Invalid selection. Exiting.${NC}"
    exit 1
fi

# Extract MAC address of selected device (array index is choice-1)
selected_device="${DEVICES[$((choice-1))]}"
TARGET_MAC=$(echo "$selected_device" | cut -d ' ' -f 2)
DEVICE_NAME=$(echo "$selected_device" | cut -d ' ' -f 3-)

echo -e "\nSelected: ${GREEN}$DEVICE_NAME ($TARGET_MAC)${NC}"

# --- Installation Steps ---

INSTALL_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config"
SYSTEMD_DIR="$HOME/.config/systemd/user"
SCRIPT_NAME="bluetooth_monitor.py"

# 1. Create Config File
echo "Creating configuration file..."
cat > "$CONFIG_DIR/bluetooth_autoconnect.conf" <<EOF
[Bluetooth]
DeviceMAC = $TARGET_MAC
DeviceName = $DEVICE_NAME
EOF
echo -e "${GREEN}✔ Config saved to $CONFIG_DIR/bluetooth_autoconnect.conf${NC}"

# 2. Install Script
echo "Installing script..."
mkdir -p "$INSTALL_DIR"
cp "src/$SCRIPT_NAME" "$INSTALL_DIR/$SCRIPT_NAME"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
echo -e "${GREEN}✔ Script installed to $INSTALL_DIR/$SCRIPT_NAME${NC}"

# 3. Create Service File
echo "Creating systemd service..."
mkdir -p "$SYSTEMD_DIR"
cat > "$SYSTEMD_DIR/bluetooth-autoconnect.service" <<EOF
[Unit]
Description=Bluetooth Auto-Connect Monitor for $DEVICE_NAME
After=bluetooth.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 "$INSTALL_DIR/$SCRIPT_NAME"
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF
echo -e "${GREEN}✔ Service file created at $SYSTEMD_DIR/bluetooth-autoconnect.service${NC}"

# 4. Enable and Start Service
echo "Enabling and starting service..."
systemctl --user daemon-reload
systemctl --user enable bluetooth-autoconnect.service
systemctl --user restart bluetooth-autoconnect.service

# Check status briefly
if systemctl --user is-active --quiet bluetooth-autoconnect.service; then
    echo -e "\n${GREEN}SUCCESS! The service is up and running.${NC}"
    echo "Your device ($DEVICE_NAME) will now auto-connect on login and wake-up."
else
    echo -e "\n${RED}WARNING: Service failed to start.${NC}"
    echo "Check status with: systemctl --user status bluetooth-autoconnect.service"
fi
