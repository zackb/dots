#!/bin/bash

# show Wi-Fi networks and connect with nmcli + wofi
IFS=$'\n'

# get list of SSIDs, mark active one
NETWORKS=$(nmcli -t -f active,ssid,signal dev wifi | awk -F: '!seen[$2]++ { print ($1=="yes" ? "✅ " : "   ") $2 "  (" $3 "%)" }')

# let user select network
CHOSEN=$(echo "$NETWORKS" | wofi --dmenu --prompt="Wi-Fi Networks" | sed -E 's/^✅ +|^ +//; s/ +\([0-9]+%\)//')
[ -z "$CHOSEN" ] && exit 1

# try to connect without password
nmcli dev wifi connect "$CHOSEN"
RESULT=$?

if [ "$RESULT" -eq 0 ]; then
    notify-send "Wi-Fi" "Connected to $CHOSEN ✅"
    exit 0
elif [ "$RESULT" -eq 4 ]; then
    # prompt for password
    PASS=$(wofi --dmenu --password --prompt="Password for $CHOSEN")
    [ -z "$PASS" ] && exit 1
    nmcli dev wifi connect "$CHOSEN" password "$PASS"

    # check if connected
    sleep 2
    if nmcli -t -f active,ssid dev wifi | grep -q "^yes:$CHOSEN$"; then
        notify-send "Wi-Fi" "Connected to $CHOSEN ✅"
        exit 0
    else
        notify-send "Wi-Fi" "Failed to connect to $CHOSEN ❌"
        exit 1
    fi
else
    notify-send "Wi-Fi" "Connection error (code $RESULT)"
    exit "$RESULT"
fi

