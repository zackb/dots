#!/bin/bash

choice=$(printf "balanced\npower-saver\nperformance" | rofi -dmenu --prompt="Power Profile:")

if [[ "$choice" != "" ]]; then
    powerprofilesctl set "$choice"
fi

