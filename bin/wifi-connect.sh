#!/bin/bash

# Check if nmcli is installed
if ! command -v nmcli &> /dev/null; then
    echo "nmcli not found. Please install NetworkManager."
    exit 1
fi

# List Wi-Fi networks
echo "Scanning for Wi-Fi networks..."
nmcli device wifi rescan
sleep 2
nmcli -f SSID,SIGNAL,SECURITY device wifi list | sed 's/^/  /'

# Prompt for SSID
echo
read -p "Enter the SSID of the Wi-Fi network you want to connect to: " ssid
if [ -z "$ssid" ]; then
    echo "SSID cannot be empty."
    exit 1
fi

# Check if the network is open or secured
security=$(nmcli -f SSID,SECURITY device wifi list | grep -F "$ssid" | head -n 1 | awk '{print $2}')

# Prompt for password if secured
if [ "$security" != "--" ] && [ -n "$security" ]; then
    echo
    nmcli device wifi connect "$ssid" --ask
else
    nmcli device wifi connect "$ssid"
fi

# Check connection status
if [ $? -eq 0 ]; then
    echo "✅ Connected to $ssid"
else
    echo "❌ Failed to connect to $ssid"
fi

