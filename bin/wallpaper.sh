#!/bin/bash

wall=$(hyprwat --wallpaper ~/.local/share/wallpapers)

if [ -n "$wall" ]; then
    sed -i "s|^\$image = .*|\$image = $wall|" ~/.config/hypr/hyprlock.conf
    # hyprpaper < 0.8.0
    sed -i "s|^preload = .*|preload = $wall|" ~/.config/hypr/hyprpaper.conf
    sed -i "s|^wallpaper =.*,.*|wallpaper = , $wall|" ~/.config/hypr/hyprpaper.conf
    # hyprpaper >= 0.8.0
    sed -i "s|^[[:space:]]*path[[:space:]]*=[[:space:]]*.*|    path = $wall|" ~/.config/hypr/hyprpaper.conf
fi

