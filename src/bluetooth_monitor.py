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

def get_target_mac():
    """Reads the MAC address from the config file."""
    config = configparser.ConfigParser()
    if not os.path.exists(CONFIG_PATH):
        print(f"Error: Configuration file not found at {CONFIG_PATH}")
        sys.exit(1)
    
    try:
        config.read(CONFIG_PATH)
        mac = config.get("Bluetooth", "DeviceMAC")
        if not mac:
            raise ValueError("DeviceMAC is empty")
        return mac
    except Exception as e:
        print(f"Error reading config file: {e}")
        sys.exit(1)

def connect_bluetooth(mac, retries=3, delay=2):
    """Attempts to connect to the Bluetooth device."""
    for attempt in range(1, retries + 1):
        print(f"Attempting to connect to {mac} (Attempt {attempt}/{retries})...")
        try:
            try:
                info = subprocess.check_output(["bluetoothctl", "info", mac], stderr=subprocess.DEVNULL).decode("utf-8")
                if "Connected: yes" in info:
                    print("Already connected.")
                    return
            except subprocess.CalledProcessError:
                pass 

            result = subprocess.run(["bluetoothctl", "connect", mac], capture_output=True, text=True)
            
            if result.returncode == 0:
                print("Connection successful.")
                return
            else:
                print(f"Connection failed: {result.stdout.strip()} {result.stderr.strip()}")
                
        except Exception as e:
            print(f"Error during connection attempt: {e}")
        
        if attempt < retries:
            time.sleep(delay)

def handle_sleep(sleeping):
    mac = get_target_mac()
    if not sleeping: # Waking up
        print("System Resuming. Waiting 5s for Bluetooth stack...")
        time.sleep(5) 
        connect_bluetooth(mac, retries=5, delay=3)
    else:
        print("System Suspending...")

def main():
    mac = get_target_mac()
    
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
    print(f"Bluetooth Monitor Service Started for device: {mac}")
    
    time.sleep(2) 
    connect_bluetooth(mac, retries=10, delay=3)
    
    try:
        loop.run()
    except KeyboardInterrupt:
        print("Exiting...")

if __name__ == "__main__":
    main()
