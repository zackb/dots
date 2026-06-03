#!/bin/bash
device=$(nmcli -t -f TYPE,STATE,CONNECTION,DEVICE device | grep ":connected:" | head -n1)
type=$(echo "$device" | cut -d: -f1)
connection=$(echo "$device" | cut -d: -f3)
iface=$(echo "$device" | cut -d: -f4)

if [ "$type" = "wifi" ]; then
    signal=$(nmcli -t -f SIGNAL,SSID device wifi | grep ":${connection}$" | head -n1 | cut -d: -f1)
    echo "{\"type\":\"wifi\",\"ssid\":\"$connection\",\"signal\":${signal:-0},\"iface\":\"$iface\"}"
elif [ "$type" = "ethernet" ]; then
    echo "{\"type\":\"ethernet\",\"ssid\":\"$connection\",\"signal\":100,\"iface\":\"$iface\"}"
else
    echo "{\"type\":\"none\",\"ssid\":\"\",\"signal\":0,\"iface\":\"\"}"
fi
