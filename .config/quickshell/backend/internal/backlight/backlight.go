// Package backlight reports screen brightness and streams changes to the shell.
package backlight

import (
	"context"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"

	"fenriz/internal/log"
	"fenriz/internal/service"
)

const Name = "backlight"

const sysDir = "/sys/class/backlight"

// State is the payload emitted to the shell; the widget derives the percentage.
type State struct {
	Brightness int `json:"brightness"`
	Max        int `json:"max"`
}

type Service struct {
	emit service.Emitter
	dir  string // chosen device directory, e.g. /sys/class/backlight/amdgpu_bl1
	max  int
	last State
	have bool
}

func New() *Service { return &Service{} }

func (s *Service) Name() string { return Name }

func (s *Service) Start(ctx context.Context, emit service.Emitter) error {
	s.emit = emit

	s.dir = findDevice()
	if s.dir == "" {
		log.Warnf("backlight: no device under %s", sysDir)
		return nil
	}
	s.max = readInt(filepath.Join(s.dir, "max_brightness"))
	log.Infof("backlight: watching %s (max %d)", s.dir, s.max)

	go s.watch(ctx)
	s.publish() // initial state
	return nil
}

// findDevice picks the backlight device: an explicit FENRIZ_BACKLIGHT_DEVICE, else
// the first entry under /sys/class/backlight that exposes max_brightness.
func findDevice() string {
	if name := strings.TrimSpace(os.Getenv("FENRIZ_BACKLIGHT_DEVICE")); name != "" {
		return filepath.Join(sysDir, name)
	}
	entries, _ := filepath.Glob(filepath.Join(sysDir, "*"))
	for _, dir := range entries {
		if _, err := os.Stat(filepath.Join(dir, "max_brightness")); err == nil {
			return dir
		}
	}
	return ""
}

// watch blocks on inotify and republishes on every brightness change. brightnessctl
// (and the kernel) write the sysfs file, which fires IN_MODIFY.
func (s *Service) watch(ctx context.Context) {
	fd, err := syscall.InotifyInit1(syscall.IN_CLOEXEC)
	if err != nil {
		log.Warnf("backlight: inotify init: %v", err)
		return
	}
	// Unblock the Read below when the daemon shuts down.
	go func() {
		<-ctx.Done()
		syscall.Close(fd)
	}()

	if _, err := syscall.InotifyAddWatch(fd, filepath.Join(s.dir, "brightness"),
		syscall.IN_MODIFY); err != nil {
		log.Warnf("backlight: add watch: %v", err)
		syscall.Close(fd)
		return
	}

	buf := make([]byte, (syscall.SizeofInotifyEvent+16)*16)
	for {
		if _, err := syscall.Read(fd, buf); err != nil {
			return // fd closed on shutdown, or read error
		}
		// We don't care which event fired, any modification means re-read.
		s.publish()
	}
}

func (s *Service) publish() {
	st := State{Brightness: readInt(filepath.Join(s.dir, "brightness")), Max: s.max}
	if s.have && st == s.last {
		return
	}
	s.last, s.have = st, true
	if s.emit != nil {
		s.emit(st)
	}
}

func readInt(path string) int {
	b, err := os.ReadFile(path)
	if err != nil {
		return 0
	}
	n, _ := strconv.Atoi(strings.TrimSpace(string(b)))
	return n
}
