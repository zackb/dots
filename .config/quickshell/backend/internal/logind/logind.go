// Package logind reports the systemd-logind events the lock screen acts on --
// Session.Lock (loginctl lock-session, the control-center Lock button, desktop
// lock actions) and PrepareForSleep -- and holds a delay inhibitor so the
// session is locked before the machine suspends.
//
// Watching PrepareForSleep alone races: logind broadcasts it and suspends
// immediately, so the compositor can sleep before the lock surface is mapped and
// briefly show the desktop on resume. A "delay" inhibitor makes logind wait for
// us to drop it, which happens once the shell confirms the lock is up or
// confirmTimeout expires.
//
// This package also fans resume out to other services, so the daemon needs only
// one system-bus connection and one PrepareForSleep match.
package logind

import (
	"context"
	"encoding/json"
	"os"
	"strconv"
	"sync"
	"syscall"
	"time"

	"github.com/godbus/dbus/v5"

	"fenriz/internal/log"
	"fenriz/internal/service"
)

const Name = "logind"

const (
	login1Service = "org.freedesktop.login1"
	login1Path    = "/org/freedesktop/login1"
	managerIface  = "org.freedesktop.login1.Manager"
	sessionIface  = "org.freedesktop.login1.Session"

	// How long we hold up the suspend waiting for the shell to say the lock
	// surface is up. Must stay under logind's InhibitDelayMaxUSec (5s by
	// default) -- overrunning it gets us suspended anyway, with a warning.
	confirmTimeout = 3 * time.Second
)

// State is one event for the shell. Transient, not a snapshot: the shell reacts
// to each event rather than diffing state.
type State struct {
	Event string `json:"event"` // "lock" | "sleep" | "resume"
}

type Service struct {
	conn    *dbus.Conn
	emit    service.Emitter
	session dbus.ObjectPath

	// Called on resume so services whose poll timers froze can refresh. Set by
	// main once every service has started.
	resumeHook func()

	// Signalled when the shell reports the lock surface is up. Buffered and
	// drained before each sleep so a late confirmation can't satisfy the next.
	confirmed chan struct{}

	mu        sync.Mutex
	inhibitFD int // -1 when not held
}

func New() *Service {
	return &Service{confirmed: make(chan struct{}, 1), inhibitFD: -1}
}

func (s *Service) Name() string { return Name }

// SetResumeHook registers the resume fan-out. Called by main after all services
// are up, so it must be safe to set while the watch goroutine is running.
func (s *Service) SetResumeHook(fn func()) {
	s.mu.Lock()
	s.resumeHook = fn
	s.mu.Unlock()
}

func (s *Service) Start(ctx context.Context, emit service.Emitter) error {
	s.emit = emit

	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		return err
	}
	s.conn = conn

	s.session, err = s.ownSession()
	if err != nil {
		conn.Close()
		return err
	}
	log.Infof("logind: watching session %s", s.session)

	// Only our own session's Lock; another user's session locking is not ours
	// to act on. Session.Unlock is deliberately ignored -- the shell calls
	// `loginctl unlock-session` itself when it unlocks, so listening here would
	// feed that straight back as a lock/unlock loop.
	if err := conn.AddMatchSignal(
		dbus.WithMatchObjectPath(s.session),
		dbus.WithMatchInterface(sessionIface),
		dbus.WithMatchMember("Lock"),
	); err != nil {
		conn.Close()
		return err
	}
	if err := conn.AddMatchSignal(
		dbus.WithMatchObjectPath(login1Path),
		dbus.WithMatchInterface(managerIface),
		dbus.WithMatchMember("PrepareForSleep"),
	); err != nil {
		conn.Close()
		return err
	}

	s.acquireInhibitor()

	go func() {
		<-ctx.Done()
		s.releaseInhibitor()
		s.conn.Close()
	}()
	go s.watch(ctx)
	return nil
}

// ownSession resolves the session this process belongs to. The PID lookup is
// authoritative; $XDG_SESSION_ID is only a fallback because it differs between
// the graphical session and any terminal. Paths come from logind rather than
// being built by hand: it escapes ids, so session "3" is at .../session/_33.
func (s *Service) ownSession() (dbus.ObjectPath, error) {
	mgr := s.conn.Object(login1Service, login1Path)

	var path dbus.ObjectPath
	err := mgr.Call(managerIface+".GetSessionByPID", 0, uint32(os.Getpid())).Store(&path)
	if err == nil {
		return path, nil
	}
	// Fall back to the inherited id if the PID lookup is unavailable.
	if id := os.Getenv("XDG_SESSION_ID"); id != "" {
		if _, e := strconv.Atoi(id); e == nil {
			if e := mgr.Call(managerIface+".GetSession", 0, id).Store(&path); e == nil {
				return path, nil
			}
		}
	}
	return "", err
}

func (s *Service) watch(ctx context.Context) {
	ch := make(chan *dbus.Signal, 16)
	s.conn.Signal(ch)

	for {
		select {
		case <-ctx.Done():
			return
		case sig, ok := <-ch:
			if !ok {
				return
			}
			switch sig.Name {
			case sessionIface + ".Lock":
				s.emit(State{Event: "lock"})

			case managerIface + ".PrepareForSleep":
				if len(sig.Body) < 1 {
					continue
				}
				going, _ := sig.Body[0].(bool)
				if going {
					s.onSleep()
				} else {
					s.onResume()
				}
			}
		}
	}
}

// onSleep tells the shell to lock, then waits (briefly) for it to confirm the
// lock surface is up before dropping the inhibitor and letting logind proceed.
func (s *Service) onSleep() {
	// Drain any stale confirmation so it can't satisfy this cycle.
	select {
	case <-s.confirmed:
	default:
	}

	s.emit(State{Event: "sleep"})

	select {
	case <-s.confirmed:
	case <-time.After(confirmTimeout):
		log.Warnf("logind: no lock confirmation in %s, suspending anyway", confirmTimeout)
	}
	s.releaseInhibitor()
}

func (s *Service) onResume() {
	// An inhibitor fd is spent once the sleep it delayed has happened; take a
	// fresh one for the next cycle.
	s.acquireInhibitor()
	s.emit(State{Event: "resume"})

	s.mu.Lock()
	hook := s.resumeHook
	s.mu.Unlock()
	if hook != nil {
		hook()
	}
}

// Command implements service.Commander. "locked" is the shell reporting that the
// lock surface is up, releasing the suspend we're holding.
func (s *Service) Command(name string, _ json.RawMessage) {
	switch name {
	case "locked":
		select {
		case s.confirmed <- struct{}{}:
		default: // already signalled; nothing waiting
		}
	default:
		log.Warnf("logind: unknown command %q", name)
	}
}

func (s *Service) acquireInhibitor() {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.inhibitFD >= 0 {
		return
	}
	var fd dbus.UnixFD
	err := s.conn.Object(login1Service, login1Path).
		Call(managerIface+".Inhibit", 0,
			"sleep", "Fenriz", "Lock the session before sleep", "delay").
		Store(&fd)
	if err != nil {
		log.Warnf("logind: inhibit: %v", err)
		return
	}
	s.inhibitFD = int(fd)
}

// releaseInhibitor closes the delay lock, allowing a pending suspend to proceed.
// Safe to call when we don't hold one.
func (s *Service) releaseInhibitor() {
	s.mu.Lock()
	fd := s.inhibitFD
	s.inhibitFD = -1
	s.mu.Unlock()
	if fd >= 0 {
		syscall.Close(fd)
	}
}
