package logind

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/godbus/dbus/v5"
)

// Resolves this process's logind session the same way the service does. Skips
// without a system bus.
func TestOwnSession(t *testing.T) {
	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		t.Skip("no system bus:", err)
	}
	defer conn.Close()

	s := &Service{conn: conn}
	path, err := s.ownSession()
	if err != nil {
		t.Fatalf("ownSession: %v", err)
	}
	t.Logf("pid=%d XDG_SESSION_ID=%q -> %s", os.Getpid(), os.Getenv("XDG_SESSION_ID"), path)
	if path == "" || path == "/" {
		t.Fatalf("unusable session path %q", path)
	}
}

// Takes a real delay inhibitor and releases it, checking the fd is live in
// between. A leaked or never-acquired inhibitor is the main failure mode, so
// this asserts both halves.
func TestInhibitorLifecycle(t *testing.T) {
	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		t.Skip("no system bus:", err)
	}
	defer conn.Close()

	s := New()
	s.conn = conn

	s.acquireInhibitor()
	if s.inhibitFD < 0 {
		t.Fatal("inhibitor not acquired")
	}
	fd := s.inhibitFD
	t.Logf("held inhibitor on fd %d", fd)

	// Re-acquiring while held must not leak a second fd.
	s.acquireInhibitor()
	if s.inhibitFD != fd {
		t.Fatalf("re-acquire replaced fd %d with %d", fd, s.inhibitFD)
	}

	s.releaseInhibitor()
	if s.inhibitFD != -1 {
		t.Fatal("inhibitor not cleared")
	}
	s.releaseInhibitor() // must be safe when not held
}

// onSleep must not block past confirmTimeout when the shell never confirms,
// otherwise a wedged shell would stall every suspend.
func TestSleepFallsBackToTimeout(t *testing.T) {
	s := New()
	var got []string
	s.emit = func(v any) { got = append(got, v.(State).Event) }

	start := time.Now()
	s.onSleep()
	elapsed := time.Since(start)

	if elapsed < confirmTimeout {
		t.Fatalf("returned after %s, expected to wait out confirmTimeout", elapsed)
	}
	if len(got) != 1 || got[0] != "sleep" {
		t.Fatalf("expected one sleep event, got %v", got)
	}
}

// A confirmation from the shell must release the suspend promptly rather than
// waiting out the timeout.
func TestSleepReleasesOnConfirm(t *testing.T) {
	s := New()
	s.emit = func(any) {}

	go func() {
		time.Sleep(50 * time.Millisecond)
		s.Command("locked", nil)
	}()

	start := time.Now()
	s.onSleep()
	if elapsed := time.Since(start); elapsed >= confirmTimeout {
		t.Fatalf("waited %s despite confirmation", elapsed)
	}
}

// A confirmation arriving late (after its cycle timed out) must not satisfy the
// next sleep.
func TestStaleConfirmIsDrained(t *testing.T) {
	s := New()
	s.emit = func(any) {}

	s.Command("locked", nil) // confirmation with no sleep in flight

	start := time.Now()
	s.onSleep()
	if elapsed := time.Since(start); elapsed < confirmTimeout {
		t.Fatalf("stale confirmation satisfied a new sleep after %s", elapsed)
	}
}

// Live end-to-end: run the service against the real bus and report the events
// it sees. Enable with FENRIZ_LOGIND_LIVE=1, then from another terminal run
// `loginctl lock-session` (or suspend) within the window.
func TestLiveEvents(t *testing.T) {
	if os.Getenv("FENRIZ_LOGIND_LIVE") == "" {
		t.Skip("set FENRIZ_LOGIND_LIVE=1 and trigger a lock/suspend to run")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	s := New()
	events := make(chan string, 8)
	if err := s.Start(ctx, func(v any) { events <- v.(State).Event }); err != nil {
		t.Fatalf("start: %v", err)
	}
	t.Logf("watching %s for 30s -- trigger `loginctl lock-session` now", s.session)

	for {
		select {
		case e := <-events:
			t.Logf("event: %s", e)
			if e == "sleep" {
				s.Command("locked", nil) // stand in for the shell
			}
		case <-ctx.Done():
			return
		}
	}
}
