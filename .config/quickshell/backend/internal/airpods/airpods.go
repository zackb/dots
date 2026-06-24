// Package airpods reports AirPods battery levels by speaking Apple's Accessory
// Protocol (AAP) over an L2CAP channel on the existing connection -- the same
// source the iPhone uses. This gives exact 1% battery (vs. the 10%-resolution
// BLE proximity beacons) and streams updates live with no scanning.
//
// We detect a connected Apple device over BlueZ D-Bus, open an L2CAP socket to
// it on PSM 0x1001, send the handshake + notification-request packets, then read
// battery notification packets. Protocol per github.com/kavishdevar/librepods.
package airpods

import (
	"bytes"
	"context"
	"encoding/hex"
	"errors"
	"strconv"
	"strings"
	"time"

	"github.com/godbus/dbus/v5"
	"golang.org/x/sys/unix"

	"fenriz/internal/log"
	"fenriz/internal/service"
)

const Name = "airpods"

const (
	bluezService = "org.bluez"
	deviceIface  = "org.bluez.Device1"
	omIface      = "org.freedesktop.DBus.ObjectManager"

	aapPSM = 0x1001 // Apple AAP L2CAP PSM

	// Battery notification components and status (librepods AAP Definitions).
	compRight = 0x02
	compLeft  = 0x04
	compCase  = 0x08
	stDisconn = 0x04

	// L2CAP security, in case a plain connect is rejected (SOL_BLUETOOTH).
	solBluetooth     = 274
	btSecurity       = 4
	btSecurityMedium = 2
)

// AAP control packets (hex per kavishdevar/librepods linux/airpods_packets.h).
// On connect we send handshake, then set-features, then request-notifications;
// without the exact request-notifications packet the AirPods never send battery.
var (
	pktHandshake = mustHex("00000400010002000000000000000000")
	pktFeatures  = mustHex("040004004d00d700000000000000")
	pktNotify    = mustHex("040004000f00ffffffffff")

	batteryPrefix   = []byte{0x04, 0x00, 0x04, 0x00, 0x04, 0x00}
	errParseAddress = errors.New("airpods: bad device address")
)

// State matches the AirpodBudBar widget semantics: pct 0-100, or -1 = hidden.
type State struct {
	Connected bool   `json:"connected"`
	Address   string `json:"address"` // connection MAC, for matching the UI row
	Left      int    `json:"left"`
	Right     int    `json:"right"`
	Case      int    `json:"case"`
}

// batteryUpdate carries the components present in one notification packet
// (component byte -> percentage, -1 = hidden). Absent components keep their
// last known value.
type batteryUpdate map[byte]int

type Service struct {
	conn   *dbus.Conn
	emit   service.Emitter
	resume chan struct{}

	// touched only from the watch goroutine
	battery      chan batteryUpdate
	connected    bool
	address      string
	left         int
	right        int
	caseB        int
	readerCancel context.CancelFunc
	last         State
	have         bool
}

func New() *Service {
	return &Service{
		resume:  make(chan struct{}, 1),
		battery: make(chan batteryUpdate, 8),
		left:    -1, right: -1, caseB: -1,
	}
}

func (s *Service) Name() string { return Name }

func (s *Service) Start(ctx context.Context, emit service.Emitter) error {
	s.emit = emit

	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		return err
	}
	s.conn = conn

	go func() {
		<-ctx.Done()
		s.conn.Close()
	}()
	go s.watch(ctx)
	return nil
}

// OnResume nudges a re-evaluation after wake; the L2CAP reader self-heals via its
// own reconnect loop, but this refreshes connection state promptly.
func (s *Service) OnResume() {
	select {
	case s.resume <- struct{}{}:
	default:
	}
}

// watch is the single owner of state: it tracks connection over D-Bus, drives the
// L2CAP reader's lifecycle, applies battery updates, and is the sole emitter.
func (s *Service) watch(ctx context.Context) {
	if err := s.conn.AddMatchSignal(
		dbus.WithMatchPathNamespace("/org/bluez"),
		dbus.WithMatchInterface("org.freedesktop.DBus.Properties"),
		dbus.WithMatchMember("PropertiesChanged"),
	); err != nil {
		log.Warnf("airpods: add match (properties): %v", err)
		return
	}
	if err := s.conn.AddMatchSignal(dbus.WithMatchInterface(omIface)); err != nil {
		log.Warnf("airpods: add match (objectmanager): %v", err)
	}

	ch := make(chan *dbus.Signal, 64)
	s.conn.Signal(ch)

	eval := stoppedTimer()
	defer s.stopReader()

	s.evaluate(ctx)
	for {
		select {
		case <-ctx.Done():
			return
		case sig, ok := <-ch:
			if !ok {
				return
			}
			if relevant(sig) {
				eval.Reset(200 * time.Millisecond)
			}
		case <-s.resume:
			eval.Reset(200 * time.Millisecond)
		case <-eval.C:
			s.evaluate(ctx)
		case u := <-s.battery:
			s.applyBattery(u)
		}
	}
}

// evaluate reads connection state and starts/stops the L2CAP reader on the edges.
func (s *Service) evaluate(ctx context.Context) {
	objects, err := s.managedObjects()
	if err != nil {
		return
	}
	connected, address := false, ""
	for _, ifaces := range objects {
		dev := ifaces[deviceIface]
		if dev == nil {
			continue
		}
		if asBool(dev["Connected"]) && looksApple(dev) {
			connected, address = true, asString(dev["Address"])
			break
		}
	}

	switch {
	case connected && !s.connected:
		s.connected, s.address = true, address
		s.left, s.right, s.caseB = -1, -1, -1
		s.publish()
		s.startReader(ctx)
	case !connected && s.connected:
		s.connected, s.address = false, ""
		s.left, s.right, s.caseB = -1, -1, -1
		s.stopReader()
		s.publish()
	case connected && address != s.address:
		s.address = address
		s.left, s.right, s.caseB = -1, -1, -1
		s.stopReader()
		s.publish()
		s.startReader(ctx)
	}
}

func (s *Service) applyBattery(u batteryUpdate) {
	if !s.connected {
		return // stale update from a torn-down reader
	}
	for comp, pct := range u {
		switch comp {
		case compLeft:
			s.left = pct
		case compRight:
			s.right = pct
		case compCase:
			s.caseB = pct
		}
	}
	s.publish()
}

func (s *Service) startReader(ctx context.Context) {
	addr, err := parseAddr(s.address)
	if err != nil {
		log.Warnf("airpods: %v (%q)", err, s.address)
		return
	}
	rctx, cancel := context.WithCancel(ctx)
	s.readerCancel = cancel
	go runReader(rctx, addr, s.battery)
}

func (s *Service) stopReader() {
	if s.readerCancel != nil {
		s.readerCancel()
		s.readerCancel = nil
	}
}

func (s *Service) publish() {
	st := State{
		Connected: s.connected, Address: s.address,
		Left: s.left, Right: s.right, Case: s.caseB,
	}
	if s.have && st == s.last {
		return
	}
	s.last, s.have = st, true
	if s.emit != nil {
		s.emit(st)
	}
}

// attemptTimeout bounds a single L2CAP attempt until it delivers its first
// battery packet. unix.Connect (and a silently-dead established channel) can
// block forever with no error, which would otherwise wedge the reader on attempt
// #1 and never reach the backoff/reconnect loop.
const attemptTimeout = 8 * time.Second

// runReader keeps an AAP session alive while ctx is live, reconnecting with
// backoff (AirPods occasionally drop the channel).
func runReader(ctx context.Context, addr [6]byte, out chan<- batteryUpdate) {
	backoff := 500 * time.Millisecond
	for {
		if ctx.Err() != nil {
			return
		}

		// Per-attempt watchdog: force the attempt to abort if it hasn't produced
		// a battery packet within attemptTimeout. Once data flows the watchdog
		// stops, so a healthy stream stays open indefinitely.
		attemptCtx, cancel := context.WithCancel(ctx)
		firstPacket := make(chan struct{}, 1)
		go func() {
			t := time.NewTimer(attemptTimeout)
			defer t.Stop()
			select {
			case <-firstPacket:
			case <-t.C:
				cancel() // closes the fd via session's ctx watcher
			case <-attemptCtx.Done():
			}
		}()

		established, err := session(attemptCtx, addr, out, firstPacket)
		cancel()
		if err != nil && ctx.Err() == nil {
			log.Warnf("airpods: l2cap session: %v", err)
		}
		if established {
			backoff = 500 * time.Millisecond // a working stream resets backoff
		}

		select {
		case <-ctx.Done():
			return
		case <-time.After(backoff):
		}
		if backoff < 5*time.Second {
			backoff *= 2
		}
	}
}

// session opens one L2CAP connection, performs the AAP handshake, and reads
// battery notifications until the socket errors or ctx is cancelled. It signals
// firstPacket once on the first decoded battery packet and reports whether the
// session ever became established (got data), so runReader can manage its
// watchdog and backoff.
func session(ctx context.Context, addr [6]byte, out chan<- batteryUpdate, firstPacket chan<- struct{}) (bool, error) {
	fd, err := unix.Socket(unix.AF_BLUETOOTH, unix.SOCK_SEQPACKET, unix.BTPROTO_L2CAP)
	if err != nil {
		return false, err
	}
	closed := make(chan struct{})
	go func() {
		select {
		case <-ctx.Done():
		case <-closed:
		}
		unix.Close(fd) // unblocks Connect/Read
	}()
	defer close(closed)

	sa := &unix.SockaddrL2{PSM: aapPSM, AddrType: unix.BDADDR_BREDR, Addr: addr}
	if err := unix.Connect(fd, sa); err != nil {
		if errors.Is(err, unix.EACCES) || errors.Is(err, unix.EPERM) {
			// Retry once requesting an authenticated link.
			_ = unix.SetsockoptInt(fd, solBluetooth, btSecurity, btSecurityMedium)
			err = unix.Connect(fd, sa)
		}
		if err != nil {
			return false, err
		}
	}
	for _, pkt := range [][]byte{pktHandshake, pktFeatures, pktNotify} {
		if _, err := unix.Write(fd, pkt); err != nil {
			return false, err
		}
	}

	established := false
	buf := make([]byte, 1024)
	for {
		n, err := unix.Read(fd, buf)
		if err != nil {
			return established, err
		}
		if u, ok := parseBattery(buf[:n]); ok {
			if !established {
				established = true
				select {
				case firstPacket <- struct{}{}:
				default:
				}
			}
			select {
			case out <- u:
			case <-ctx.Done():
				return established, nil
			}
		}
	}
}

// parseBattery decodes an AAP battery notification:
// 04 00 04 00 04 00 [count] ([component] 01 [level] [status] 01) * count
func parseBattery(p []byte) (batteryUpdate, bool) {
	if len(p) < 7 || !bytes.HasPrefix(p, batteryPrefix) {
		return nil, false
	}
	count := int(p[6])
	u := batteryUpdate{}
	for off := 7; count > 0 && off+5 <= len(p); count, off = count-1, off+5 {
		comp, level, status := p[off], p[off+2], p[off+3]
		pct := -1
		if status != stDisconn && level <= 100 {
			pct = int(level)
		}
		switch comp {
		case compLeft, compRight, compCase:
			u[comp] = pct
		}
	}
	if len(u) == 0 {
		return nil, false
	}
	return u, true
}

func (s *Service) managedObjects() (map[dbus.ObjectPath]map[string]map[string]dbus.Variant, error) {
	var objects map[dbus.ObjectPath]map[string]map[string]dbus.Variant
	err := s.conn.Object(bluezService, "/").
		Call(omIface+".GetManagedObjects", 0).Store(&objects)
	if err != nil {
		return nil, err
	}
	return objects, nil
}

// relevant reports whether a BlueZ signal warrants a connection re-evaluation:
// a Device1 Connected change, or any interface added/removed.
func relevant(sig *dbus.Signal) bool {
	if strings.HasSuffix(sig.Name, "PropertiesChanged") {
		if len(sig.Body) < 2 {
			return false
		}
		if iface, _ := sig.Body[0].(string); iface != deviceIface {
			return false
		}
		changed, _ := sig.Body[1].(map[string]dbus.Variant)
		_, ok := changed["Connected"]
		return ok
	}
	return strings.Contains(sig.Name, "Interfaces")
}

// looksApple reports whether a connected Device1 is Apple gear: Modalias vendor
// 0x004C, else a name containing "airpod".
func looksApple(dev map[string]dbus.Variant) bool {
	if strings.HasPrefix(strings.ToLower(asString(dev["Modalias"])), "bluetooth:v004c") {
		return true
	}
	name := asString(dev["Name"])
	if name == "" {
		name = asString(dev["Alias"])
	}
	return strings.Contains(strings.ToLower(name), "airpod")
}

// parseAddr converts "F8:D3:F0:3C:84:4A" into a 6-byte address in natural order.
// SockaddrL2.sockaddr() reverses it to the kernel's little-endian layout, so we
// must NOT reverse here.
func parseAddr(s string) ([6]byte, error) {
	parts := strings.Split(s, ":")
	if len(parts) != 6 {
		return [6]byte{}, errParseAddress
	}
	var a [6]byte
	for i, p := range parts {
		v, err := strconv.ParseUint(p, 16, 8)
		if err != nil {
			return [6]byte{}, errParseAddress
		}
		a[i] = byte(v)
	}
	return a, nil
}

func mustHex(s string) []byte {
	b, err := hex.DecodeString(s)
	if err != nil {
		panic(err)
	}
	return b
}

func stoppedTimer() *time.Timer {
	t := time.NewTimer(time.Hour)
	if !t.Stop() {
		<-t.C
	}
	return t
}

func asBool(v dbus.Variant) bool     { b, _ := v.Value().(bool); return b }
func asString(v dbus.Variant) string { s, _ := v.Value().(string); return s }
