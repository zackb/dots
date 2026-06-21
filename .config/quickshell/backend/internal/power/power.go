// Package power watches the system for resume-from-suspend events over the
// logind system D-Bus and notifies a callback. It exists so services whose poll
// timers freeze while the machine is asleep can refresh promptly on wake without
// each opening its own bus connection.
package power

import (
	"context"

	"github.com/godbus/dbus/v5"
)

const (
	login1Path  = "/org/freedesktop/login1"
	login1Iface = "org.freedesktop.login1.Manager"
)

// Watch calls onResume each time the system resumes from suspend, until ctx is
// cancelled. It returns an error if the system bus is unavailable; callers
// should treat that as non-fatal (services keep running, just without the
// resume nudge). onResume runs on Watch's goroutine, so it must not block.
func Watch(ctx context.Context, onResume func()) error {
	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		return err
	}
	if err := conn.AddMatchSignal(
		dbus.WithMatchInterface(login1Iface),
		dbus.WithMatchMember("PrepareForSleep"),
		dbus.WithMatchObjectPath(login1Path),
	); err != nil {
		conn.Close()
		return err
	}

	ch := make(chan *dbus.Signal, 8)
	conn.Signal(ch)
	go func() {
		defer conn.Close()
		for {
			select {
			case <-ctx.Done():
				return
			case sig, ok := <-ch:
				if !ok {
					return
				}
				if len(sig.Body) < 1 {
					continue
				}
				// PrepareForSleep is true just before suspend, false on resume.
				if going, _ := sig.Body[0].(bool); going {
					continue
				}
				onResume()
			}
		}
	}()
	return nil
}
