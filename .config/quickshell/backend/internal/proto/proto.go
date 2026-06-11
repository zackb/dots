// Package proto defines the wire format between the backend daemon and the
// Quickshell front-end. The shell launches the daemon as a child process and
// reads its stdout; every event is one line of JSON:
//
//	{"service":"screensaver","data":{...}}
//
// Commands flow the other way over stdin in the same shape:
//
//	{"service":"screensaver","command":"...","args":{...}}
//
// This keeps the integration to a Quickshell Process + SplitParser with no
// socket lifecycle to manage, while staying generic across services.
package proto

import (
	"encoding/json"
	"io"
	"sync"
)

// Event is one outbound message: a service name and an arbitrary payload.
type Event struct {
	Service string `json:"service"`
	Data    any    `json:"data"`
}

// Command is one inbound message from the shell.
type Command struct {
	Service string          `json:"service"`
	Command string          `json:"command"`
	Args    json.RawMessage `json:"args,omitempty"`
}

// Writer serializes events to an io.Writer as newline-delimited JSON. It is
// safe for concurrent use; services emit from their own goroutines.
type Writer struct {
	mu  sync.Mutex
	enc *json.Encoder
}

func NewWriter(w io.Writer) *Writer {
	return &Writer{enc: json.NewEncoder(w)}
}

// Emit writes one event line. Encode appends the trailing newline.
func (w *Writer) Emit(service string, data any) {
	w.mu.Lock()
	defer w.mu.Unlock()
	_ = w.enc.Encode(Event{Service: service, Data: data})
}
