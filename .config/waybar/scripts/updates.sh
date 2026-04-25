#!/bin/bash
# Dependencies: pacman-contrib (checkupdates), yay

threshold_none=0
threshold_green=1
threshold_yellow=25
threshold_red=50

if [[ ! -f /etc/arch-release ]]; then
    echo '{"text": "Unsupported platform"}'
    exit 1
fi

aur_helper=$(command -v yay || command -v paru || echo "")
if [[ -z "$aur_helper" ]]; then
    echo '{"text": "󰇚 No AUR helper found"}'
    exit 1
fi

if ! command -v checkupdates &>/dev/null; then
    echo '{"text": "󰇚 Missing pacman-contrib"}'
    exit 1
fi

repo_updates=$(checkupdates 2>/dev/null | wc -l)
aur_updates=$("$aur_helper" -Qua 2>/dev/null | wc -l)
flatpak_updates=$(flatpak remote-ls --updates 2>/dev/null | wc -l)
updates=$((repo_updates + aur_updates + flatpak_updates))

css_class="none"
if [[ "$updates" -ge "$threshold_green" ]]; then css_class="green"; fi
if [[ "$updates" -ge "$threshold_yellow" ]]; then css_class="yellow"; fi
if [[ "$updates" -ge "$threshold_red" ]]; then css_class="red"; fi

tooltip="Repo: $repo_updates | AUR: $aur_updates | Flatpak: $flatpak_updates"

if [[ "$updates" -le "$threshold_none" ]]; then
    printf '{"text": "", "class": "none"}\n'
else
    printf '{"text": " %s", "alt": "%s", "tooltip": "%s", "class": "%s"}\n' \
        "$updates" "$updates" "$tooltip" "$css_class"
fi

exit 0
