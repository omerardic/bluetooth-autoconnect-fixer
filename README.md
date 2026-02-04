# Bluetooth Auto-Connect Fixer for Linux

A lightweight service designed to fix the common issue on Linux (especially with Systemd and BlueZ) where paired Bluetooth devices fail to automatically reconnect after a system reboot or wake-from-sleep cycle.

**New in v2:** Now supports monitoring and auto-connecting to **multiple devices**!

## How it works
This tool installs a background monitor that:
1.  **On Startup:** Attempts to connect to all configured devices automatically
2.  **On Wake:** Listens for system resume signals (DBus) and automatically triggers a reconnection attempt for all devices after a short delay.

## Prerequisites
- **Linux** with `systemd` (most modern distributions like Fedora, Ubuntu, Debian, Arch).
- **Python 3**
- **BlueZ** (provides `bluetoothctl`)
- **DBus** Python libraries (`python3-dbus`, `python3-gi`)

## Installation & Usage

**Quick Install (Recommended):**
Copy and run this command in your terminal. It will download the latest version and start the setup manager.
```bash
curl -L https://github.com/omerardic/bluetooth-autoconnect-fixer/archive/main.tar.gz | tar xz && cd bluetooth-autoconnect-fixer-main && ./bt-autoconnect-manage.sh
```

**Manual Install (via Git):**
1.  Clone the repository:
    ```bash
    git clone https://github.com/omerardic/bluetooth-autoconnect-fixer.git
    cd bluetooth-autoconnect-fixer
    ```
2.  Run the Manager Script:
    ```bash
    ./bt-autoconnect-manage.sh
    ```

3.  **Follow the Menu:**
    *   **Option 3 (Install/Re-install):** Run this first to set up the systemd service.
    *   **Option 1 (Add a new device):** Select paired devices from the list to add them to the monitor.
    *   **Option 2 (Remove a device):** Stop monitoring a specific device.

## Uninstallation
To remove the service and all associated files, use the Manager script:
1.  Run `./bt-autoconnect-manage.sh`
2.  Choose option **4 (Uninstall Service)**.

## Troubleshooting
If the service is running but not connecting, you can check the logs using:
```bash
journalctl --user -u bluetooth-autoconnect.service -f
```

## Contributing
Feel free to open issues or submit pull requests to improve the script or installer!
