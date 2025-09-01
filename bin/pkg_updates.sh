#!/bin/bash

# repo updates
repo=$(checkupdates 2> /dev/null | wc -l)

# aur updates
aur=$(paru -Qua 2> /dev/null | wc -l)

total=$((repo + aur))

if [ "$total" -gt 0 ]; then
    echo "$total"
else
    # print nothing so waybar hides it
    echo ""
fi

