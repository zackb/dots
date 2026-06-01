"""
Waybar MLB Score Module — Seattle Mariners
Fetches today's Mariners game from the MLB Stats API (no key required).
Outputs plain-text JSON for Waybar — no Pango markup, styled via CSS only.
"""

import json
import sys
import urllib.request
import urllib.error
from datetime import datetime, timezone

# ── Config ───────────────────────────────────────────────────────────────────
MY_TEAM      = "SEA"
MY_TEAM_NAME = "Mariners"

# ── Glyph ────────────────────────────────────────────────────────────────────
GLYPH = ""

def fetch(url):
    req = urllib.request.Request(url, headers={
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:124.0) Gecko/20100101 Firefox/124.0",
        "Accept": "application/json",
    })
    with urllib.request.urlopen(req, timeout=8) as r:
        return json.loads(r.read().decode())

def game_status_short(code):
    if code in {"I", "MA", "MC"}:             return "LIVE"
    if code in {"F", "FT", "FR", "O", "UR"}: return "F"
    return "PRE"

def innings_label(linescore):
    try:
        half   = "T" if linescore.get("inningHalf", "") == "Top" else "B"
        inning = linescore.get("currentInning", "")
        return f"{half}{inning}"
    except Exception:
        return ""

def format_game(game):
    teams     = game["teams"]
    home      = teams["home"]
    away      = teams["away"]
    h_abbr    = home["team"]["abbreviation"]
    a_abbr    = away["team"]["abbreviation"]
    h_score   = home.get("score", 0) or 0
    a_score   = away.get("score", 0) or 0
    status    = game["status"]
    code      = status.get("codedGameState", "P")
    state     = game_status_short(code)
    linescore = game.get("linescore", {})

    if state == "LIVE":
        inn       = innings_label(linescore)
        state_str = f" ● {inn}"
        css_class = "mlb-live"
    elif state == "F":
        state_str = " F"
        css_class = "mlb-final"
    else:
        game_time = game.get("gameDate", "")
        try:
            dt        = datetime.fromisoformat(game_time.replace("Z", "+00:00"))
            local     = dt.astimezone()
            state_str = f" {local.strftime('%-I:%M%p').lower()}"
        except Exception:
            state_str = ""
        css_class = "mlb-pre"

    text    = f"{GLYPH} {h_abbr} {h_score}  {GLYPH} {a_abbr} {a_score}{state_str} "
    tooltip = (
        f"{home['team']['teamName']} vs {away['team']['teamName']}\n"
        f"Score: {h_score} – {a_score}\n"
        f"Status: {status.get('detailedState', state)}"
    )
    return text, tooltip, css_class

def main():
    today = datetime.now().strftime("%Y-%m-%d")
    # today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    url   = f"https://statsapi.mlb.com/api/v1/schedule?sportId=1&date={today}&hydrate=linescore,team"

    try:
        data  = fetch(url)
        dates = data.get("dates", [])
        games = dates[0]["games"] if dates else []
    except urllib.error.URLError as e:
        print(json.dumps({"text": f"", "tooltip": str(e), "class": "mlb-error"}))
        sys.exit(0)
    except Exception as e:
        print(json.dumps({"text": f"", "tooltip": str(e), "class": "mlb-error"}))
        sys.exit(0)

    my_games = [
        g for g in games
        if g["teams"]["home"]["team"]["abbreviation"] == MY_TEAM
        or g["teams"]["away"]["team"]["abbreviation"] == MY_TEAM
    ]

    if not my_games:
        print(json.dumps({
            # "text":    f"{GLYPH} {MY_TEAM} off",
            "text":    f"",
            "tooltip": f"No {MY_TEAM_NAME} game today",
            "class":   "mlb-idle"
        }))
        return

    def sort_key(g):
        c = g["status"].get("codedGameState", "P")
        if game_status_short(c) == "LIVE": return 0
        if game_status_short(c) == "PRE":  return 1
        return 2

    game = sorted(my_games, key=sort_key)[0]
    text, tooltip, css_class = format_game(game)
    print(json.dumps({"text": text, "tooltip": tooltip, "class": css_class}))

if __name__ == "__main__":
    main()
