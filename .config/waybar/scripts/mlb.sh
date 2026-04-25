#!/usr/bin/env python3
"""
Waybar MLB Score Module — Seattle Mariners
Fetches today's Mariners game from the MLB Stats API (no key required).
Outputs JSON for Waybar custom module consumption.

Format: HOME ⚾ score  away ⚾ score  [● inning | time | F]
Uses Pango markup for color coding (winning team brighter).
"""

import json
import sys
import urllib.request
import urllib.error
from datetime import datetime, timezone

# ── Config ──────────────────────────────────────────────────────────────────
MY_TEAM = "SEA"   # Change to any team abbreviation (e.g. "LAD", "NYY")

# ── Team colors (primary hex) ───────────────────────────────────────────────
TEAM_COLORS = {
    "ARI": "#A71930", "ATL": "#CE1141", "BAL": "#DF4601", "BOS": "#BD3039",
    "CHC": "#0E3386", "CWS": "#27251F", "CIN": "#C6011F", "CLE": "#E31937",
    "COL": "#333366", "DET": "#0C2340", "HOU": "#EB6E1F", "KC":  "#004687",
    "LAA": "#BA0021", "LAD": "#005A9C", "MIA": "#00A3E0", "MIL": "#FFC52F",
    "MIN": "#002B5C", "NYM": "#002D72", "NYY": "#003087", "OAK": "#003831",
    "PHI": "#E81828", "PIT": "#FDB827", "SD":  "#2F241D", "SEA": "#005C5C",
    "SF":  "#FD5A1E", "STL": "#C41E3A", "TB":  "#092C5C", "TEX": "#003278",
    "TOR": "#134A8E", "WSH": "#AB0003",
}

# Nerd Font / Unicode glyphs per team (⚾ fallback if not defined)
TEAM_GLYPHS = {
    # You can replace these with  nf-md-baseball or custom icons
    "default": "⚾",
}

def fetch(url):
    req = urllib.request.Request(url, headers={
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:124.0) Gecko/20100101 Firefox/124.0",
        "Accept": "application/json",
    })
    with urllib.request.urlopen(req, timeout=8) as r:
        return json.loads(r.read().decode())

def game_status_short(status_code):
    """Map abstractGameState + codedGameState to a short label."""
    live_codes  = {"I", "MA", "MC"}   # In Progress / Manager Challenge
    pre_codes   = {"P", "S", "PW", "NF", "PI"}
    final_codes = {"F", "FT", "FR", "O", "UR"}
    if status_code in live_codes:  return "LIVE"
    if status_code in final_codes: return "F"
    return "PRE"

def innings_label(linescore):
    """Return e.g. 'T7' / 'B9' / 'F' from linescore data."""
    try:
        inning     = linescore.get("currentInning", "")
        inning_half = linescore.get("inningHalf", "")
        half = "T" if inning_half == "Top" else "B"
        return f"{half}{inning}"
    except Exception:
        return ""

def team_span(abbr, score, winning):
    """Return a Pango-marked-up team+score string."""
    color = TEAM_COLORS.get(abbr, "#CCCCCC")
    glyph = TEAM_GLYPHS.get(abbr, TEAM_GLYPHS["default"])
    alpha = "ff" if winning else "99"
    # Pango foreground with alpha isn't universally supported; use brightness trick
    dim   = "" if winning else "<span alpha='60%'>"
    undim = "" if winning else "</span>"
    return f"{dim}<span foreground='{color}'>{glyph}</span> {abbr} <b>{score}</b>{undim}"

def format_game(game):
    """Return (text, tooltip) for a single game dict."""
    teams    = game["teams"]
    home     = teams["home"]
    away     = teams["away"]
    h_abbr   = home["team"]["abbreviation"]
    a_abbr   = away["team"]["abbreviation"]
    h_score  = home.get("score", 0) or 0
    a_score  = away.get("score", 0) or 0
    status   = game["status"]
    code     = status.get("codedGameState", "P")
    state    = game_status_short(code)
    linescore = game.get("linescore", {})

    h_winning = h_score > a_score
    a_winning = a_score > h_score

    h_span = team_span(h_abbr, h_score, h_winning or state == "PRE")
    a_span = team_span(a_abbr, a_score, a_winning or state == "PRE")

    if state == "LIVE":
        inn = innings_label(linescore)
        state_label = f"<span foreground='#FF4444'> ● {inn}</span>"
    elif state == "F":
        state_label = "<span foreground='#888888'> F</span>"
    else:
        # PRE — show scheduled time
        game_time = game.get("gameDate", "")
        try:
            dt = datetime.fromisoformat(game_time.replace("Z", "+00:00"))
            local = dt.astimezone()
            state_label = f"<span foreground='#888888'> {local.strftime('%-I:%M%p').lower()}</span>"
        except Exception:
            state_label = ""

    text    = f"{h_span}  {a_span}{state_label}"
    tooltip = (
        f"{home['team']['teamName']} vs {away['team']['teamName']}\n"
        f"Score: {h_score} – {a_score}\n"
        f"Status: {status.get('detailedState', state)}"
    )
    return text, tooltip

def main():
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    url   = f"https://statsapi.mlb.com/api/v1/schedule?sportId=1&date={today}&hydrate=linescore,team"

    try:
        data  = fetch(url)
        dates = data.get("dates", [])
        games = dates[0]["games"] if dates else []
    except urllib.error.URLError as e:
        out = {"text": "⚾ offline", "tooltip": str(e), "class": "error"}
        print(json.dumps(out))
        sys.exit(0)
    except Exception as e:
        out = {"text": "⚾ –", "tooltip": str(e), "class": "error"}
        print(json.dumps(out))
        sys.exit(0)

    # Filter to just MY_TEAM's game
    my_games = [
        g for g in games
        if g["teams"]["home"]["team"]["abbreviation"] == MY_TEAM
        or g["teams"]["away"]["team"]["abbreviation"] == MY_TEAM
    ]

    if not my_games:
        print(json.dumps({"text": "⚾ SEA off today", "tooltip": "No Mariners game today", "class": "idle"}))
        return

    # In rare case of doubleheader, show the live/upcoming one first
    def sort_key(g):
        c = g["status"].get("codedGameState", "P")
        if game_status_short(c) == "LIVE": return 0
        if game_status_short(c) == "PRE":  return 1
        return 2

    game = sorted(my_games, key=sort_key)[0]
    text, tooltip = format_game(game)

    # Set class to "mlb-live" when in progress for CSS pulse animation
    code  = game["status"].get("codedGameState", "P")
    state = game_status_short(code)
    css_class = "mlb-live" if state == "LIVE" else "mlb-scores"

    print(json.dumps({"text": text, "tooltip": tooltip, "class": css_class}))

if __name__ == "__main__":
    main()
