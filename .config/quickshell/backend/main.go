// Command fenrizd is the Fenriz shell's backend daemon. Quickshell launches it
// as a child process; it owns DBus services Quickshell can't host and streams
// state to the shell as newline-delimited JSON on stdout. Commands may be sent
// back on stdin. It exits when the launching shell goes away, so there is never
// an orphaned daemon.
//
// Adding a capability: implement service.Service and append it to services below.
package main

import (
	"bufio"
	"context"
	"encoding/json"
	"flag"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"fenriz/internal/airpods"
	"fenriz/internal/backlight"
	"fenriz/internal/calendar"
	"fenriz/internal/clipboard"
	"fenriz/internal/contacts"
	"fenriz/internal/log"
	"fenriz/internal/logind"
	"fenriz/internal/mlb"
	"fenriz/internal/network"
	"fenriz/internal/proto"
	"fenriz/internal/screensaver"
	"fenriz/internal/service"
	"fenriz/internal/sysinfo"
	"fenriz/internal/wifi"
)

func main() {
	// Re-exec path: `wl-paste --watch` invokes us as the per-copy store routine.
	// Handle it before any daemon setup and exit.
	if len(os.Args) > 1 && os.Args[1] == clipboard.ClipStoreFlag {
		if err := clipboard.RunStore(); err != nil {
			log.Warnf("clip-store: %v", err)
			os.Exit(1)
		}
		return
	}

	// Services the shell should disable
	disable := flag.String("disable", "", "comma-separated service names to skip")
	flag.Parse()

	disabled := map[string]bool{}
	for _, name := range strings.Split(*disable, ",") {
		if name = strings.TrimSpace(name); name != "" {
			disabled[name] = true
		}
	}

	ctx, cancel := signal.NotifyContext(context.Background(),
		syscall.SIGINT, syscall.SIGTERM)
	defer cancel()

	// Exit when the shell that launched us goes away. We can't rely on stdin
	// EOF (Quickshell may hand the child an inherited stdin that never closes),
	// so watch our parent: when the shell dies we're reparented (to init or a
	// systemd subreaper) and getppid() changes from its launch-time value.
	go watchParentDeath(cancel)

	writer := proto.NewWriter(os.Stdout)

	// logind is first: it holds the suspend delay inhibitor, so it should be
	// live before anything slower can stall startup.
	logindSvc := logind.New()

	services := []service.Service{
		logindSvc,
		screensaver.New(),
		mlb.New(),
		network.New(),
		wifi.New(),
		sysinfo.New(),
		backlight.New(),
		calendar.New(),
		contacts.New(),
		clipboard.New(),
		airpods.New(),
	}

	commanders := map[string]service.Commander{}
	var resumers []service.Resumer
	for _, svc := range services {
		name := svc.Name()
		if disabled[name] {
			log.Infof("service %q disabled", name)
			continue
		}
		emit := func(data any) { writer.Emit(name, data) }
		if err := svc.Start(ctx, emit); err != nil {
			log.Warnf("service %q failed to start: %v", name, err)
			continue
		}
		if c, ok := svc.(service.Commander); ok {
			commanders[name] = c
		}
		if r, ok := svc.(service.Resumer); ok {
			resumers = append(resumers, r)
		}
		log.Infof("service %q started", name)
	}

	// The logind service already watches PrepareForSleep for the lock screen;
	// it fans resume out to the services whose poll timers froze while asleep.
	if len(resumers) > 0 && !disabled[logind.Name] {
		logindSvc.SetResumeHook(func() {
			for _, r := range resumers {
				r.OnResume()
			}
		})
	}

	// Read stdin for commands and for EOF: when the shell exits it closes our
	// stdin, which is our cue to shut down.
	go func() {
		sc := bufio.NewScanner(os.Stdin)
		for sc.Scan() {
			var cmd proto.Command
			if err := json.Unmarshal(sc.Bytes(), &cmd); err != nil {
				continue
			}
			if c, ok := commanders[cmd.Service]; ok {
				go c.Command(cmd.Command, cmd.Args)
			}
		}
		cancel()
	}()

	<-ctx.Done()
	log.Infof("shutting down")
}

func watchParentDeath(cancel context.CancelFunc) {
	parent := os.Getppid()
	if parent <= 1 { // already orphaned at startup
		cancel()
		return
	}
	t := time.NewTicker(time.Second)
	defer t.Stop()
	for range t.C {
		if os.Getppid() != parent {
			log.Infof("parent %d gone, shutting down", parent)
			cancel()
			return
		}
	}
}
