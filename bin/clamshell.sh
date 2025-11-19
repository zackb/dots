#!/bin/bash

# internal monitor name
INTERNAL_MONITOR="eDP-1"

while true; do
    # Check lid state
    if grep -q "closed" /proc/acpi/button/lid/LID0/state; then
        LID_CLOSED=true
    else
        LID_CLOSED=false
    fi

    # count monitors that are NOT the internal one
    EXTERNAL_MONITOR_COUNT=$(hyprctl -j monitors | jq "[.[] | select(.name != \"$INTERNAL_MONITOR\")] | length")

    if [ "$LID_CLOSED" = true ] && [ "$EXTERNAL_MONITOR_COUNT" -gt 0 ]; then
        # lid is closed and external monitor exists, disable internal
        # check if it's already disabled to avoid spamming commands
        if ! hyprctl monitors | grep -q "$INTERNAL_MONITOR"; then
             # safety check - if it's missing, we don't need to do anything
             :
        else
             hyprctl keyword monitor "$INTERNAL_MONITOR,disable"
        fi
    else
        # lid is open or no external monitor, enable internal
        # check if it is missing from active monitors
        # if it is in the list, we don't need to do anything.
        if ! hyprctl monitors | grep -q "$INTERNAL_MONITOR"; then
            hyprctl keyword monitor "$INTERNAL_MONITOR,preferred,auto,1.5"
        fi
    fi

    sleep 1
done
