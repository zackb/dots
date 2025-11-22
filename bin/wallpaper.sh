#!/bin/bash
wall=$(hyprwat --wallpaper ~/.local/share/wallpapers)
sed -i "s|^\$image = .*|\$image = $wall|" ~/.config/hypr/hyprlock.conf

