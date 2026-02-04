# Bluetooth Auto-Connect Fixer for Linux

A lightweight service designed to fix the common issue on Linux (especially with Systemd and BlueZ) where paired Bluetooth devices fail to automatically reconnect after a system reboot or wake-from-sleep cycle.

## How it works
This tool installs a background monitor that:
1.  **On Startup:** Attempts to connect to your specified device multiple times until successful.
2.  **On Wake:** Listens for system resume signals (DBus) and automatically triggers a reconnection attempt after a short delay to allow the Bluetooth stack to initialize.

## Prerequisites
- **Linux** with `systemd` (most modern distributions like Fedora, Ubuntu, Debian, Arch).
- **Python 3**
- **BlueZ** (provides `bluetoothctl`)
- **DBus** Python libraries (`python3-dbus`, `python3-gi`)

## Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/omerardic/bluetooth-autoconnect-fixer.git
    cd bluetooth-autoconnect-fixer
    ```

2.  **Run the installer:**
    ```bash
    ./install.sh
    ```
    Follow the on-screen instructions to select your Bluetooth device from the list.

## Uninstallation
To remove the service and all associated files, run:
```bash
./uninstall.sh
```

## Troubleshooting
If the service is running but not connecting, you can check the logs using:
```bash
journalctl --user -u bluetooth-autoconnect.service -f
```

## Contributing
Feel free to open issues or submit pull requests to improve the script or installer!
