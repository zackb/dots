#!/bin/bash
# ~/.config/eww/scripts/calendar.sh
# Parse Thunderbird calendar for upcoming events

# Path to Thunderbird profile calendar storage
# You'll need to adjust this to your actual profile path
TB_PROFILE="$HOME/.thunderbird/*.default-release/calendar-data"


# Using khal if installed (recommended)
if command -v khal &> /dev/null; then
    # Get next 3 events
    khal list --format "{start-time} {title}" today 7d 2>/dev/null | head -3
    exit 0
fi

# Fallback: basic ICS parsing (very simplified)
# This is a starting point - ICS parsing is complex
if [ -f "$HOME/.local/share/calendar.ics" ]; then
    # Extract SUMMARY lines (event titles) - very basic
    grep "SUMMARY:" "$HOME/.local/share/calendar.ics" | \
        sed 's/SUMMARY://' | \
        head -3
else
    echo "No upcoming events"
    echo ""
    echo "Install 'khal' for calendar"
    echo "or configure ICS file path"
fi
