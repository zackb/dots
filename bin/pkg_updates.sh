#!/bin/bash

# repo updates
repo=$(checkupdates 2> /dev/null | wc -l)

# aur updates (paru example)
aur=$(paru -Qua 2> /dev/null | wc -l)

echo "$((repo + aur))"
