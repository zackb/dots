// Package wifi manages Wi-Fi from the shell: it lists nearby access points and
// the radio state, and accepts commands to scan, connect (with a password),
// forget a saved network, and toggle the radio. All actions go through nmcli,
// which already brokers the WPA secret agent so passwords need no extra plumbing.
//
// The passive primary-connection indicator stays in the separate `network`
// service (godbus); this service is command-driven and only emits in response to
// a command or the shell's open-popup poll.
package wifi

import (
	"context"
	"encoding/json"
	"os/exec"
	"sort"
	"strconv"
	"strings"
	"sync"

	"fenriz/internal/log"
	"fenriz/internal/service"
)

const Name = "wifi"

// Network is one access point in the emitted list.
type Network struct {
	SSID    string `json:"ssid"`
	Signal  int    `json:"signal"`  // 0-100
	Secured bool   `json:"secured"` // has any SECURITY
	Active  bool   `json:"active"`  // currently connected (IN-USE "*")
	Saved   bool   `json:"saved"`   // a saved wifi connection profile exists
}

// State is the full wifi payload sent to the shell.
type State struct {
	Enabled    bool      `json:"enabled"`
	Connecting bool      `json:"connecting"`
	Error      string    `json:"error"` // last connect failure, "" once it succeeds
	Networks   []Network `json:"networks"`
}

type Service struct {
	emit service.Emitter

	mu         sync.Mutex // guards the transient connect status below
	connecting bool
	lastErr    string
}

func New() *Service { return &Service{} }

func (s *Service) Name() string { return Name }

func (s *Service) Start(_ context.Context, emit service.Emitter) error {
	s.emit = emit
	s.publish() // initial list so the icon's popup has data before first open
	return nil
}

// Command implements service.Commander: scan/list/connect/forget/radio.
func (s *Service) Command(name string, raw json.RawMessage) {
	var a struct {
		SSID     string `json:"ssid"`
		Password string `json:"password"`
		On       bool   `json:"on"`
	}
	_ = json.Unmarshal(raw, &a)

	switch name {
	case "scan":
		// Best-effort rescan; results trickle into the cache that `list` reads.
		_ = exec.Command("nmcli", "dev", "wifi", "rescan").Run()
		s.publish()
	case "list":
		s.publish()
	case "connect":
		go s.connect(a.SSID, a.Password) // nmcli connect blocks; don't stall stdin
	case "forget":
		if out, err := exec.Command("nmcli", "connection", "delete", "id", a.SSID).CombinedOutput(); err != nil {
			log.Warnf("wifi: forget %q: %v: %s", a.SSID, err, strings.TrimSpace(string(out)))
		}
		s.publish()
	case "radio":
		state := "off"
		if a.On {
			state = "on"
		}
		if out, err := exec.Command("nmcli", "radio", "wifi", state).CombinedOutput(); err != nil {
			log.Warnf("wifi: radio %s: %v: %s", state, err, strings.TrimSpace(string(out)))
		}
		s.publish()
	default:
		log.Warnf("wifi: unknown command %q", name)
	}
}

// connect activates a network, reporting connecting/error status around the call.
func (s *Service) connect(ssid, password string) {
	s.mu.Lock()
	s.connecting, s.lastErr = true, ""
	s.mu.Unlock()
	s.publish()

	args := []string{"dev", "wifi", "connect", ssid}
	if password != "" {
		args = append(args, "password", password)
	}
	out, err := exec.Command("nmcli", args...).CombinedOutput()

	s.mu.Lock()
	s.connecting = false
	if err != nil {
		s.lastErr = cleanErr(string(out))
		log.Warnf("wifi: connect %q: %v: %s", ssid, err, strings.TrimSpace(string(out)))
	} else {
		s.lastErr = ""
	}
	s.mu.Unlock()
	s.publish()
}

func (s *Service) publish() {
	if s.emit == nil {
		return
	}
	st := State{Enabled: radioEnabled(), Networks: listNetworks()}
	s.mu.Lock()
	st.Connecting, st.Error = s.connecting, s.lastErr
	s.mu.Unlock()
	s.emit(st)
}

func radioEnabled() bool {
	out, err := exec.Command("nmcli", "-t", "-f", "WIFI", "radio").Output()
	if err != nil {
		return false
	}
	return strings.TrimSpace(string(out)) == "enabled"
}

// listNetworks returns visible APs, deduped by SSID (strongest kept) and sorted
// with the active one first, then by signal descending.
func listNetworks() []Network {
	saved := savedSSIDs()

	out, err := exec.Command("nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list").Output()
	if err != nil {
		return []Network{}
	}

	byName := map[string]Network{}
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		if line == "" {
			continue
		}
		f := splitTerse(line)
		if len(f) < 4 {
			continue
		}
		ssid := f[1]
		if ssid == "" {
			continue // hidden network, no SSID to act on
		}
		sig, _ := strconv.Atoi(f[2])
		n := Network{
			SSID:    ssid,
			Signal:  sig,
			Secured: strings.TrimSpace(f[3]) != "",
			Active:  strings.TrimSpace(f[0]) == "*",
			Saved:   saved[ssid],
		}
		if ex, ok := byName[ssid]; ok {
			if n.Signal < ex.Signal {
				ex.Active = ex.Active || n.Active
				byName[ssid] = ex
				continue
			}
			n.Active = n.Active || ex.Active
		}
		byName[ssid] = n
	}

	list := make([]Network, 0, len(byName))
	for _, n := range byName {
		list = append(list, n)
	}
	sort.Slice(list, func(i, j int) bool {
		if list[i].Active != list[j].Active {
			return list[i].Active
		}
		return list[i].Signal > list[j].Signal
	})
	return list
}

// savedSSIDs is the set of NAMEs of saved 802-11-wireless connection profiles.
func savedSSIDs() map[string]bool {
	m := map[string]bool{}
	out, err := exec.Command("nmcli", "-t", "-f", "NAME,TYPE", "connection", "show").Output()
	if err != nil {
		return m
	}
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		if line == "" {
			continue
		}
		f := splitTerse(line)
		if len(f) >= 2 && f[1] == "802-11-wireless" {
			m[f[0]] = true
		}
	}
	return m
}

// splitTerse splits one nmcli `-t` line on unescaped colons, unescaping the
// backslash escapes nmcli uses for literal ':' and '\' inside field values.
func splitTerse(line string) []string {
	var fields []string
	var cur strings.Builder
	for i := 0; i < len(line); i++ {
		switch c := line[i]; {
		case c == '\\' && i+1 < len(line):
			cur.WriteByte(line[i+1])
			i++
		case c == ':':
			fields = append(fields, cur.String())
			cur.Reset()
		default:
			cur.WriteByte(c)
		}
	}
	return append(fields, cur.String())
}

// cleanErr reduces nmcli's stderr to a single human line for the popup footer.
func cleanErr(s string) string {
	s = strings.TrimSpace(s)
	if i := strings.IndexByte(s, '\n'); i >= 0 {
		s = s[:i]
	}
	return strings.TrimPrefix(s, "Error: ")
}
