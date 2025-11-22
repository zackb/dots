#!/bin/bash
wall=$(hyprwat --wallpaper ~/.local/share/wallpapers)
if [ -n "$wall" ]; then
    sed -i "s|^\$image = .*|\$image = $wall|" ~/.config/hypr/hyprlock.conf
fi
