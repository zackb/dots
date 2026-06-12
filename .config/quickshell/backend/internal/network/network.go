// Package network reports the primary network connection (type, name, signal) and
// streams changes to the shell. Reads NetworkManager over the system D-Bus and
// re-publishes whenever a relevant property changes.
package network

import (
	"context"

	"github.com/godbus/dbus/v5"

	"fenriz/internal/log"
	"fenriz/internal/service"
)

const Name = "network"

const (
	nmService = "org.freedesktop.NetworkManager"
	nmPath    = "/org/freedesktop/NetworkManager"

	nmIface     = "org.freedesktop.NetworkManager"
	activeIface = "org.freedesktop.NetworkManager.Connection.Active"
	deviceIface = "org.freedesktop.NetworkManager.Device"
	wirelessIfc = "org.freedesktop.NetworkManager.Device.Wireless"
	apIface     = "org.freedesktop.NetworkManager.AccessPoint"
)

// State matches the JSON the old script produced, so the widget is a drop-in.
type State struct {
	Type   string `json:"type"`   // "wifi" | "ethernet" | "none"
	SSID   string `json:"ssid"`   // active connection Id (the profile name)
	Signal int    `json:"signal"` // 0-100; 100 for ethernet, 0 when down
	Iface  string `json:"iface"`
}

type Service struct {
	conn *dbus.Conn
	emit service.Emitter
	last State
	have bool
}

func New() *Service { return &Service{} }

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

	s.publish() // initial state
	return nil
}

// watch re-reads and republishes whenever any NetworkManager object signals a
// property change (primary connection, device state, AP strength, ...).
func (s *Service) watch(ctx context.Context) {
	if err := s.conn.AddMatchSignal(
		dbus.WithMatchPathNamespace(nmPath),
		dbus.WithMatchInterface("org.freedesktop.DBus.Properties"),
		dbus.WithMatchMember("PropertiesChanged"),
	); err != nil {
		log.Warnf("network: add match: %v", err)
		return
	}
	ch := make(chan *dbus.Signal, 64)
	s.conn.Signal(ch)
	for {
		select {
		case <-ctx.Done():
			return
		case _, ok := <-ch:
			if !ok {
				return
			}
			s.publish()
		}
	}
}

func (s *Service) publish() {
	st := s.read()
	if s.have && st == s.last {
		return // dedup: only emit on real change
	}
	s.last, s.have = st, true
	if s.emit != nil {
		s.emit(st)
	}
}

// read resolves the current primary connection into a State.
func (s *Service) read() State {
	nm := s.conn.Object(nmService, nmPath)

	var primary dbus.ObjectPath
	if err := get(nm, nmIface, "PrimaryConnection", &primary); err != nil || primary == "/" {
		return State{Type: "none"}
	}
	active := s.conn.Object(nmService, primary)

	var id, ctype string
	get(active, activeIface, "Id", &id)
	get(active, activeIface, "Type", &ctype)

	st := State{SSID: id}
	switch ctype {
	case "802-11-wireless":
		st.Type = "wifi"
	case "802-3-ethernet":
		st.Type = "ethernet"
		st.Signal = 100
	default:
		st.Type = "none"
		return State{Type: "none"}
	}

	var devices []dbus.ObjectPath
	get(active, activeIface, "Devices", &devices)
	if len(devices) == 0 {
		return st
	}
	dev := s.conn.Object(nmService, devices[0])
	get(dev, deviceIface, "Interface", &st.Iface)

	if st.Type == "wifi" {
		st.Signal = s.wifiStrength(dev)
	}
	return st
}

// wifiStrength reads the active access point's signal strength (0-100).
func (s *Service) wifiStrength(dev dbus.BusObject) int {
	var ap dbus.ObjectPath
	if err := get(dev, wirelessIfc, "ActiveAccessPoint", &ap); err != nil || ap == "/" {
		return 0
	}
	var strength byte
	get(s.conn.Object(nmService, ap), apIface, "Strength", &strength)
	return int(strength)
}

// get reads one D-Bus property into out.
func get(obj dbus.BusObject, iface, prop string, out any) error {
	v, err := obj.GetProperty(iface + "." + prop)
	if err != nil {
		return err
	}
	return v.Store(out)
}
