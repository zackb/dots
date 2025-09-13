#!/bin/bash

WALLPAPER_DIRECTORY=~/.local/share/wallpapers

WALLPAPER=$(find "$WALLPAPER_DIRECTORY" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) | shuf -n 1)


hyprctl hyprpaper preload "$WALLPAPER"
hyprctl hyprpaper wallpaper ", $WALLPAPER"

sleep 1

hyprctl hyprpaper unload unused

