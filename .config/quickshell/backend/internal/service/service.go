// Package service defines the plugin contract every backend module implements.
// Adding a capability to the shell backend means writing a Service and
// registering it in main -- the daemon wiring, event stream and command
// dispatch are shared.
package service

import (
	"context"
	"encoding/json"
)

// Emitter publishes a payload as an event for this service. The daemon binds
// the service's name, so a service only supplies the data.
type Emitter func(data any)

// Service is a long-lived backend module.
type Service interface {
	// Name is the stable identifier used to route events and commands
	// (e.g. "screensaver"). It must be unique across registered services.
	Name() string

	// Start brings the service up. It should return quickly, doing ongoing
	// work in its own goroutines, and tear down when ctx is cancelled. A
	// non-nil error means the service is unavailable; the daemon logs it and
	// continues with the others.
	Start(ctx context.Context, emit Emitter) error
}

// Commander is an optional interface for services that accept commands from the
// shell over stdin.
type Commander interface {
	Command(name string, args json.RawMessage)
}
