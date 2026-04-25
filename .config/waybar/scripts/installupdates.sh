#!/bin/bash
# Dependencies: figlet, gum, libnotify, yay, pacman-contrib (for paccache)

dependencies=("figlet" "gum" "notify-send" "yay")
missing=()
for dep in "${dependencies[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
        missing+=("$dep")
    fi
done
if [[ ${#missing[@]} -gt 0 ]]; then
    echo " ERROR - Missing dependencies: ${missing[*]}"
    exit 1
fi

sleep 0.2
clear
figlet -f smslant "Updates"
echo

echo " Checking for updates..."
repo_updates=$(checkupdates 2>/dev/null)
aur_updates=$(yay -Qua 2>/dev/null)
repo_count=$(echo "$repo_updates" | grep -c . || true)
aur_count=$(echo "$aur_updates" | grep -c . || true)
total=$((repo_count + aur_count))

if [[ $total -eq 0 ]]; then
    echo " System is up to date. Nothing to do."
    notify-send "Updates" "System is already up to date."
    exit 0
fi

echo " $repo_count repo update(s), $aur_count AUR update(s) available."
echo

if ! gum confirm "START UPDATE NOW? ($total packages)"; then
    echo
    echo " Update canceled."
    exit 0
fi

echo
echo " Starting update..."
echo

yay -Syu --noconfirm
echo

if command -v flatpak &>/dev/null; then
    echo " Updating Flatpak packages..."
    flatpak update --noninteractive
    echo
fi

orphans=$(pacman -Qdtq 2>/dev/null)
if [[ -n "$orphans" ]]; then
    echo " Found orphaned packages:"
    echo "$orphans"
    echo
    if gum confirm "REMOVE ORPHANED PACKAGES?"; then
        sudo pacman -Rns $orphans --noconfirm
        echo " Orphaned packages removed."
    else
        echo " Skipping orphan removal."
    fi
else
    echo " No orphaned packages found."
fi
echo

if gum confirm "CLEAN PACKAGE CACHE?"; then
    yay -Sccd --noconfirm
    if command -v paccache &>/dev/null; then
        sudo paccache -r
        echo " Package cache cleaned."
    else
        echo " paccache not found, skipping (install pacman-contrib)."
    fi
fi

notify-send "Updates" "System update complete."
echo
echo " Update complete."
echo
echo "Press [ENTER] to close."
read
