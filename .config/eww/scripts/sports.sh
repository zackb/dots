#!/bin/bash
# ~/.config/eww/scripts/sports.sh
# ESPN API for sports scores

# Example teams - modify these to your teams
# Format: "SPORT:TEAM_ABBREVIATION"
TEAMS=(
    "nfl:SEA"      # Seattle Seahawks
    "nba:POR"      # Portland Trail Blazers
    "mlb:LAD"      # Los Angeles Dodgers
)

output=""

for team_info in "${TEAMS[@]}"; do
    sport=$(echo "$team_info" | cut -d: -f1)
    team=$(echo "$team_info" | cut -d: -f2)
    
    # ESPN API endpoint (unofficial but works)
    url="https://site.api.espn.com/apis/site/v2/sports/${sport}/scoreboard"
    
    # Fetch and parse JSON (requires jq)
    if command -v jq &> /dev/null; then
        data=$(curl -s "$url" 2>/dev/null)
        
        # Find game with this team
        game=$(echo "$data" | jq -r --arg TEAM "$team" '
            .events[] | 
            select(.competitions[0].competitors[].team.abbreviation == $TEAM) |
            .competitions[0] |
            "\(.competitors[0].team.abbreviation) \(.competitors[0].score // "0") - \(.competitors[1].score // "0") \(.competitors[1].team.abbreviation) (\(.status.type.shortDetail))"
        ' | head -1)
        
        if [ -n "$game" ]; then
            output+="$game\n"
        else
            output+="$team: No game today\n"
        fi
    else
        output+="Install jq for scores\n"
        break
    fi
done

if [ -z "$output" ]; then
    echo "No scores available"
else
    echo -e "$output" | sed 's/\\n$//'
fi
