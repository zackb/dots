// Package screensaver owns the org.freedesktop.ScreenSaver (and
// org.gnome.ScreenSaver) DBus names and tracks idle-inhibit requests from apps
// like browsers and VLC. Quickshell cannot host a DBus service, so this is the
// piece that lets the shell honour DBus idle inhibitors the way hypridle did --
// while the Wayland idle-inhibit protocol is handled natively by Quickshell's
// IdleMonitor.respectInhibitors.
//
// On every change it emits the current inhibitor set; the shell pauses its
// dim/lock idle monitors while any inhibitor is active.
package screensaver

import (
	"context"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"

	"github.com/godbus/dbus/v5"
	"github.com/godbus/dbus/v5/introspect"

	"fenriz/internal/log"
	"fenriz/internal/service"
)

const Name = "screensaver"

// Inhibitor is one active idle-inhibit request. peer (the caller's unique bus
// name) is unexported so it never leaks into the JSON the shell sees.
type Inhibitor struct {
	Cookie uint32 `json:"cookie"`
	App    string `json:"app"`
	Reason string `json:"reason"`
	peer   string
}

// State is the payload emitted to the shell.
type State struct {
	Inhibited  bool        `json:"inhibited"`
	Count      int         `json:"count"`
	Inhibitors []Inhibitor `json:"inhibitors"`
}

type Service struct {
	conn    *dbus.Conn
	emit    service.Emitter
	mu      sync.Mutex
	items   []Inhibitor
	counter uint32
}

func New() *Service { return &Service{} }

func (s *Service) Name() string { return Name }

func (s *Service) Start(ctx context.Context, emit service.Emitter) error {
	s.emit = emit

	conn, err := dbus.ConnectSessionBus()
	if err != nil {
		return err
	}
	s.conn = conn

	h := &handler{s: s}
	// The freedesktop name is served on both object paths apps use; the gnome
	// name mirrors the same handler/interface so org.gnome.ScreenSaver callers
	// work too.
	fd := s.claim(h, "org.freedesktop.ScreenSaver", "org.freedesktop.ScreenSaver",
		"/ScreenSaver", "/org/freedesktop/ScreenSaver")
	gnome := s.claim(h, "org.gnome.ScreenSaver", "org.gnome.ScreenSaver",
		"/org/gnome/ScreenSaver")
	if !fd && !gnome {
		log.Warnf("screensaver: no name could be claimed (another idle daemon running?)")
	}

	go s.watchPeerDisconnects(ctx)
	go func() {
		<-ctx.Done()
		s.conn.Close()
	}()

	s.publish() // initial "nothing inhibiting" state
	return nil
}

// claim requests a bus name and, on success, exports the handler + an
// introspection node on each path. Returns false (without error) if the name is
// already owned, mirroring DoNotQueue semantics.
func (s *Service) claim(h *handler, name, iface string, paths ...dbus.ObjectPath) bool {
	reply, err := s.conn.RequestName(name, dbus.NameFlagDoNotQueue)
	if err != nil {
		log.Warnf("screensaver: request name %s: %v", name, err)
		return false
	}
	if reply != dbus.RequestNameReplyPrimaryOwner {
		log.Infof("screensaver: %s already owned by another process", name)
		return false
	}
	for _, path := range paths {
		if err := s.conn.Export(h, path, iface); err != nil {
			log.Warnf("screensaver: export %s on %s: %v", iface, path, err)
			continue
		}
		node := &introspect.Node{
			Name: string(path),
			Interfaces: []introspect.Interface{
				introspect.IntrospectData,
				ifaceIntrospect(iface),
			},
		}
		if err := s.conn.Export(introspect.NewIntrospectable(node), path,
			"org.freedesktop.DBus.Introspectable"); err != nil {
			log.Warnf("screensaver: export introspectable on %s: %v", path, err)
		}
	}
	log.Infof("screensaver: claimed %s", name)
	return true
}

// watchPeerDisconnects drops inhibitors held by a client that fell off the bus,
// so a crashed video app can't pin the screen awake forever.
func (s *Service) watchPeerDisconnects(ctx context.Context) {
	if err := s.conn.AddMatchSignal(
		dbus.WithMatchInterface("org.freedesktop.DBus"),
		dbus.WithMatchMember("NameOwnerChanged"),
	); err != nil {
		log.Warnf("screensaver: watch disconnects: %v", err)
		return
	}
	ch := make(chan *dbus.Signal, 64)
	s.conn.Signal(ch)
	for {
		select {
		case <-ctx.Done():
			return
		case sig, ok := <-ch:
			if !ok {
				return
			}
			if sig.Name != "org.freedesktop.DBus.NameOwnerChanged" || len(sig.Body) < 3 {
				continue
			}
			name, _ := sig.Body[0].(string)
			newOwner, _ := sig.Body[2].(string)
			if newOwner != "" { // name still owned; only act on disappearance
				continue
			}
			s.removeByPeer(name)
		}
	}
}

func (s *Service) add(in Inhibitor) {
	s.mu.Lock()
	s.items = append(s.items, in)
	s.mu.Unlock()
	s.publish()
}

func (s *Service) removeByCookie(cookie uint32) {
	s.mu.Lock()
	changed := false
	for i, in := range s.items {
		if in.Cookie == cookie {
			s.items = append(s.items[:i], s.items[i+1:]...)
			changed = true
			break
		}
	}
	s.mu.Unlock()
	if changed {
		s.publish()
	}
}

func (s *Service) removeByPeer(peer string) {
	s.mu.Lock()
	kept := s.items[:0:0]
	removed := 0
	for _, in := range s.items {
		if in.peer == peer {
			removed++
			continue
		}
		kept = append(kept, in)
	}
	s.items = kept
	s.mu.Unlock()
	if removed > 0 {
		log.Infof("screensaver: peer %s gone, dropped %d inhibitor(s)", peer, removed)
		s.publish()
	}
}

func (s *Service) publish() {
	s.mu.Lock()
	items := make([]Inhibitor, len(s.items))
	copy(items, s.items)
	s.mu.Unlock()
	if s.emit != nil {
		s.emit(State{Inhibited: len(items) > 0, Count: len(items), Inhibitors: items})
	}
}

// handler implements the DBus methods. godbus treats a method as a DBus method
// when its final return is *dbus.Error; a leading dbus.Sender arg is filled with
// the caller's unique name.
type handler struct{ s *Service }

func (h *handler) Inhibit(sender dbus.Sender, app, reason string) (uint32, *dbus.Error) {
	if app == "" {
		return 0, dbus.NewError("org.freedesktop.DBus.Error.InvalidArgs",
			[]any{"application name required"})
	}
	// Ignore audio-only inhibits: a music player alone shouldn't keep the
	// screen awake. Video players include "video" in the reason.
	rl := strings.ToLower(reason)
	if strings.Contains(rl, "audio") && !strings.Contains(rl, "video") {
		log.Infof("screensaver: ignoring audio-only inhibit from %s: %q", app, reason)
		return 0, nil
	}
	app = filepath.Base(app)
	cookie := atomic.AddUint32(&h.s.counter, 1)
	h.s.add(Inhibitor{Cookie: cookie, App: app, Reason: reason, peer: string(sender)})
	log.Infof("screensaver: inhibited by %s (%s): %q -> %08X", app, sender, reason, cookie)
	return cookie, nil
}

func (h *handler) UnInhibit(sender dbus.Sender, cookie uint32) *dbus.Error {
	h.s.removeByCookie(cookie)
	return nil
}

// Remaining interface methods are stubs; we don't run a real screensaver, we
// only broker inhibitors. They exist so introspection-driven callers don't trip.
func (h *handler) GetActive() (bool, *dbus.Error)         { return false, nil }
func (h *handler) SetActive(bool) (bool, *dbus.Error)     { return false, nil }
func (h *handler) GetActiveTime() (uint32, *dbus.Error)   { return 0, nil }
func (h *handler) GetSessionIdleTime() (uint32, *dbus.Error) { return 0, nil }
func (h *handler) SimulateUserActivity() *dbus.Error      { return nil }
func (h *handler) Lock() *dbus.Error                      { return nil }

func ifaceIntrospect(name string) introspect.Interface {
	return introspect.Interface{
		Name: name,
		Methods: []introspect.Method{
			{Name: "Inhibit", Args: []introspect.Arg{
				{Name: "application_name", Type: "s", Direction: "in"},
				{Name: "reason_for_inhibit", Type: "s", Direction: "in"},
				{Name: "cookie", Type: "u", Direction: "out"},
			}},
			{Name: "UnInhibit", Args: []introspect.Arg{
				{Name: "cookie", Type: "u", Direction: "in"},
			}},
			{Name: "GetActive", Args: []introspect.Arg{
				{Name: "active", Type: "b", Direction: "out"},
			}},
			{Name: "SetActive", Args: []introspect.Arg{
				{Name: "e", Type: "b", Direction: "in"},
				{Name: "active", Type: "b", Direction: "out"},
			}},
			{Name: "GetActiveTime", Args: []introspect.Arg{
				{Name: "seconds", Type: "u", Direction: "out"},
			}},
			{Name: "GetSessionIdleTime", Args: []introspect.Arg{
				{Name: "seconds", Type: "u", Direction: "out"},
			}},
			{Name: "SimulateUserActivity"},
			{Name: "Lock"},
		},
		Signals: []introspect.Signal{
			{Name: "ActiveChanged", Args: []introspect.Arg{{Name: "new_value", Type: "b"}}},
		},
	}
}
