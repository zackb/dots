#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/.local/share/wallpapers"

mapfile -t IMAGES < <(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \))

mapfile -t NAMES < <(for img in "${IMAGES[@]}"; do basename "$img"; done)

SELECTED_NAME=$(printf '%s\n' "${NAMES[@]}" | rofi -dmenu -i -p "Wallpaper:" -no-custom)

for i in "${!NAMES[@]}"; do
    if [[ "${NAMES[$i]}" == "$SELECTED_NAME" ]]; then
        SELECTED_PATH="${IMAGES[$i]}"
        break
    fi
done

if [[ -n "$SELECTED_PATH" ]]; then
    hyprctl hyprpaper preload "$SELECTED_PATH"
    hyprctl hyprpaper wallpaper ", $SELECTED_PATH"
    sleep 1
    hyprctl hyprpaper unload unused
fi

