#!/usr/bin/env python3
import dbus
import dbus.mainloop.glib
from gi.repository import GLib
import subprocess
import time
import sys
import os
import configparser

# Configuration Path
CONFIG_PATH = os.path.expanduser("~/.config/bluetooth_autoconnect.conf")

def get_monitored_devices():
    """Reads all devices from the [Devices] section of the config file."""
    # Fix: Only allow '=' as delimiter so MAC addresses with ':' are treated as keys
    config = configparser.ConfigParser(delimiters=('=',))
    if not os.path.exists(CONFIG_PATH):
        print(f"Configuration file not found at {CONFIG_PATH}")
        return {}
    
    try:
        config.read(CONFIG_PATH)
        if "Devices" not in config:
            return {}
        
        # Returns a dict of {mac: name}
        return dict(config.items("Devices"))
    except Exception as e:
        print(f"Error reading config file: {e}")
        return {}

def connect_device(mac, name, retries=3, delay=2):
    """Attempts to connect to a single Bluetooth device."""
    for attempt in range(1, retries + 1):
        print(f"[{name}] Attempting to connect to {mac} (Attempt {attempt}/{retries})...")
        try:
            try:
                # Check if already connected
                info = subprocess.check_output(["bluetoothctl", "info", mac], stderr=subprocess.DEVNULL).decode("utf-8")
                if "Connected: yes" in info:
                    print(f"[{name}] Already connected.")
                    return
            except subprocess.CalledProcessError:
                pass 

            result = subprocess.run(["bluetoothctl", "connect", mac], capture_output=True, text=True)
            
            if result.returncode == 0:
                print(f"[{name}] Connection successful.")
                return
            else:
                # Don't print full error on every retry to keep logs clean, unless it's the last attempt
                if attempt == retries:
                    print(f"[{name}] Connection failed: {result.stdout.strip()} {result.stderr.strip()}")
                
        except Exception as e:
            print(f"[{name}] Error during connection attempt: {e}")
        
        if attempt < retries:
            time.sleep(delay)

def connect_all_devices(retries=3, delay=2):
    """Iterates through all configured devices and attempts connection."""
    devices = get_monitored_devices()
    if not devices:
        print("No devices configured to monitor.")
        return

    print(f"Starting connection checks for {len(devices)} device(s)...")
    for mac, name in devices.items():
        # Clean up MAC key (configparser converts keys to lowercase)
        # We need the MAC to be uppercase for bluetoothctl usually, though it often handles both.
        # Let's ensure it matches what we stored.
        # Note: configparser keys are lowercase by default. We will assume the config file writes them as keys.
        # We'll upper() the mac when passing to bluetoothctl just in case.
        mac_upper = mac.upper()
        connect_device(mac_upper, name, retries, delay)

def handle_sleep(sleeping):
    if not sleeping: # Waking up
        print("System Resuming. Waiting 5s for Bluetooth stack...")
        time.sleep(5) 
        connect_all_devices(retries=5, delay=3)
    else:
        print("System Suspending...")

def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    
    try:
        bus = dbus.SystemBus()
    except Exception as e:
        print(f"Failed to connect to SystemBus: {e}")
        sys.exit(1)
    
    bus.add_signal_receiver(
        handle_sleep,
        signal_name='PrepareForSleep',
        dbus_interface='org.freedesktop.login1.Manager',
        bus_name='org.freedesktop.login1'
    )

    loop = GLib.MainLoop()
    print("Bluetooth Monitor Service Started.")
    
    # Try connecting on start
    time.sleep(2) 
    connect_all_devices(retries=10, delay=3)
    
    try:
        loop.run()
    except KeyboardInterrupt:
        print("Exiting...")

if __name__ == "__main__":
    main()
