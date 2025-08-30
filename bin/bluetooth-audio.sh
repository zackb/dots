#!/usr/bin/env bash

# Run rofi-bluetooth to pick/connect/disconnect device
DEVICE_MAC=$(rofi-bluetooth --select)
if [ -z "$DEVICE_MAC" ]; then
    exit 0
fi

# Give PipeWire a moment to register the sink
sleep 2

# Get card & sink names
CARD="bluez_card.${DEVICE_MAC//:/_}"
SINK=$(pactl list short sinks | awk -v mac="${DEVICE_MAC//:/_}" '$2 ~ mac {print $2; exit}')

if [ -n "$SINK" ]; then
    # Ensure profile is A2DP if available
    pactl set-card-profile "$CARD" a2dp-sink 2>/dev/null

    # Set as default sink
    pactl set-default-sink "$SINK"

    # Move all active streams
    for input in $(pactl list short sink-inputs | awk '{print $1}'); do
        pactl move-sink-input "$input" "$SINK"
    done
fi

