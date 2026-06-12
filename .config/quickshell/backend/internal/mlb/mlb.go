// Package mlb tracks the configured team's MLB game and streams a compact
// scoreboard to the shell. Uses the MLB Stats API
// It polls every couple of minutes during a live game and otherwise sleeps
// until just before first pitch when a game is hours away, or until the next
// day when there's no game or the game is over
//
// The team is configurable via the FENRIZ_MLB_TEAM env var ("SEA" or "LAD").
// Defaults to Seattle of course. Team cap logos are downloaded once and
// cached on disk, and their paths are handed to the shell so the widget can draw
package mlb

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"fenriz/internal/log"
	"fenriz/internal/service"
)

const Name = "mlb"

const (
	defaultTeam = "SEA"
	scheduleURL = "https://statsapi.mlb.com/api/v1/schedule?sportId=1&date=%s&hydrate=linescore,team"
	logoURL     = "https://www.mlbstatic.com/team-logos/%d.svg"
	userAgent   = "Mozilla/5.0 (X11; Linux x86_64; rv:124.0) Gecko/20100101 Firefox/124.0"

	livePoll  = 2 * time.Minute  // refresh cadence while a game is in progress
	preBuffer = 10 * time.Minute // wake this long before a scheduled first pitch
	errRetry  = 5 * time.Minute  // back off this long after a fetch failure
)

// Team is one club's line in the scoreboard. Logo is a local file path (or empty if
// the cap logo couldn't be fetched).
type Team struct {
	Abbr  string `json:"abbr"`
	Name  string `json:"name"`
	Score int    `json:"score"`
	Logo  string `json:"logo"`
}

// State is the payload emitted to the shell. Active is false (game idle / error)
// when there's nothing worth showing, which the widget treats as "hide me".
type State struct {
	Active  bool   `json:"active"`
	Class   string `json:"class"` // mlb-live | mlb-final | mlb-pre | mlb-idle | mlb-error
	Status  string `json:"status"`
	Tooltip string `json:"tooltip"`
	Home    Team   `json:"home"`
	Away    Team   `json:"away"`
}

type Service struct {
	team    string
	logoDir string
	client  *http.Client
	emit    service.Emitter
}

func New() *Service {
	team := strings.ToUpper(strings.TrimSpace(os.Getenv("FENRIZ_MLB_TEAM")))
	if team == "" {
		team = defaultTeam
	}
	dir := ""
	if cache, err := os.UserCacheDir(); err == nil {
		dir = filepath.Join(cache, "fenriz", "mlb-logos")
	}
	return &Service{
		team:    team,
		logoDir: dir,
		client:  &http.Client{Timeout: 8 * time.Second},
	}
}

func (s *Service) Name() string { return Name }

func (s *Service) Start(ctx context.Context, emit service.Emitter) error {
	s.emit = emit
	go s.run(ctx)
	return nil
}

// run polls, emits, then sleeps for a state-dependent interval until ctx ends.
func (s *Service) run(ctx context.Context) {
	for {
		st, next := s.poll(ctx)
		s.emit(st)
		select {
		case <-ctx.Done():
			return
		case <-time.After(next):
		}
	}
}

func (s *Service) poll(ctx context.Context) (State, time.Duration) {
	now := time.Now()
	games, err := s.fetch(ctx, fmt.Sprintf(scheduleURL, now.Format("2006-01-02")))
	if err != nil {
		log.Warnf("mlb: fetch: %v", err)
		return State{Active: false, Class: "mlb-error", Tooltip: err.Error()}, errRetry
	}

	game, ok := s.pick(games)
	if !ok {
		return State{
			Active:  false,
			Class:   "mlb-idle",
			Tooltip: fmt.Sprintf("No %s game today", s.team),
		}, untilNextMorning(now)
	}
	return s.format(game, now)
}

// MLB Stats API

type apiResponse struct {
	Dates []struct {
		Games []apiGame `json:"games"`
	} `json:"dates"`
}

type apiGame struct {
	GameDate string `json:"gameDate"`
	Status   struct {
		CodedGameState string `json:"codedGameState"`
		DetailedState  string `json:"detailedState"`
	} `json:"status"`
	Teams struct {
		Home apiSide `json:"home"`
		Away apiSide `json:"away"`
	} `json:"teams"`
	Linescore struct {
		CurrentInning int    `json:"currentInning"`
		InningHalf    string `json:"inningHalf"`
	} `json:"linescore"`
}

type apiSide struct {
	Score int `json:"score"`
	Team  struct {
		ID           int    `json:"id"`
		Abbreviation string `json:"abbreviation"`
		TeamName     string `json:"teamName"`
	} `json:"team"`
}

func (s *Service) fetch(ctx context.Context, url string) ([]apiGame, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept", "application/json")

	resp, err := s.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("status %s", resp.Status)
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	var data apiResponse
	if err := json.Unmarshal(body, &data); err != nil {
		return nil, err
	}
	if len(data.Dates) == 0 {
		return nil, nil
	}
	return data.Dates[0].Games, nil
}

// pick narrows the day's games to the configured team and chooses the most
// interesting one: a live game over an upcoming one over a finished one. This
// keeps doubleheaders sane.
func (s *Service) pick(games []apiGame) (apiGame, bool) {
	var mine []apiGame
	for _, g := range games {
		if g.Teams.Home.Team.Abbreviation == s.team || g.Teams.Away.Team.Abbreviation == s.team {
			mine = append(mine, g)
		}
	}
	if len(mine) == 0 {
		return apiGame{}, false
	}
	sort.SliceStable(mine, func(i, j int) bool { return rank(mine[i]) < rank(mine[j]) })
	return mine[0], true
}

type phase int

const (
	pre phase = iota
	live
	final
)

func phaseOf(code string) phase {
	switch code {
	case "I", "MA", "MC":
		return live
	case "F", "FT", "FR", "O", "UR":
		return final
	default:
		return pre
	}
}

func rank(g apiGame) int {
	switch phaseOf(g.Status.CodedGameState) {
	case live:
		return 0
	case pre:
		return 1
	default:
		return 2
	}
}

// format builds the emitted State and the duration to sleep before the next poll.
func (s *Service) format(g apiGame, now time.Time) (State, time.Duration) {
	home := s.side(g.Teams.Home)
	away := s.side(g.Teams.Away)

	st := State{
		Active: true,
		Home:   home,
		Away:   away,
		Tooltip: fmt.Sprintf("%s vs %s\nScore: %d – %d\nStatus: %s",
			home.Name, away.Name, home.Score, away.Score, g.Status.DetailedState),
	}

	var next time.Duration
	switch phaseOf(g.Status.CodedGameState) {
	case live:
		half := "T"
		if !strings.EqualFold(g.Linescore.InningHalf, "Top") {
			half = "B"
		}
		st.Class = "mlb-live"
		st.Status = fmt.Sprintf("● %s%d", half, g.Linescore.CurrentInning)
		next = livePoll

	case final:
		st.Class = "mlb-final"
		st.Status = "F"
		next = untilNextMorning(now)

	default: // pre-game
		st.Class = "mlb-pre"
		next = livePoll // about to start: keep an eye on it
		if start, err := time.Parse(time.RFC3339, g.GameDate); err == nil {
			st.Status = strings.ToLower(start.Local().Format("3:04PM"))
			if d := time.Until(start); d > 15*time.Minute {
				next = d - preBuffer // hours away: sleep until just before first pitch
			}
		}
	}
	return st, next
}

func (s *Service) side(a apiSide) Team {
	return Team{
		Abbr:  a.Team.Abbreviation,
		Name:  a.Team.TeamName,
		Score: a.Score,
		Logo:  s.logo(a.Team.ID),
	}
}

// Logos

// logo returns a local path to the team's cap logo, downloading it once. A
// failure is non-fatal: the widget falls back to text when the path is empty.
func (s *Service) logo(id int) string {
	if s.logoDir == "" || id == 0 {
		return ""
	}
	path := filepath.Join(s.logoDir, fmt.Sprintf("%d.svg", id))
	if _, err := os.Stat(path); err == nil {
		return path
	}
	if err := os.MkdirAll(s.logoDir, 0o755); err != nil {
		log.Warnf("mlb: logo dir: %v", err)
		return ""
	}
	if err := s.download(fmt.Sprintf(logoURL, id), path); err != nil {
		log.Warnf("mlb: logo %d: %v", id, err)
		return ""
	}
	return path
}

// download fetches url to dst atomically (write temp, rename) so a partial file
// can never be served as a cached logo.
func (s *Service) download(url, dst string) error {
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", userAgent)
	resp, err := s.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("status %s", resp.Status)
	}
	tmp, err := os.CreateTemp(s.logoDir, "logo-*.tmp")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name())
	if _, err := io.Copy(tmp, resp.Body); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmp.Name(), dst)
}

// untilNextMorning is the sleep used when there's nothing happening today: wake
// just after the next local midnight, when the new day's schedule exists.
func untilNextMorning(now time.Time) time.Duration {
	next := time.Date(now.Year(), now.Month(), now.Day(), 0, 10, 0, 0, now.Location()).
		Add(24 * time.Hour)
	if d := next.Sub(now); d > time.Minute {
		return d
	}
	return time.Minute
}
