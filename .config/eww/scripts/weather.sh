#!/bin/bash
# ~/.config/eww/scripts/weather.sh
# Simple weather script using wttr.in

LOCATION="Portland,Oregon"  # Change to your location

# Get weather data - format: condition, temp, feels like
weather=$(curl -s "wttr.in/${LOCATION}?format=%C+%t+feels+like+%f" 2>/dev/null)

if [ $? -eq 0 ] && [ -n "$weather" ]; then
    echo "$weather"
else
    echo "Weather unavailable"
fi

# Alternative with more detail (uncomment to use):
# curl -s "wttr.in/${LOCATION}?format=3" 2>/dev/null
