package network

import (
	"testing"

	"github.com/godbus/dbus/v5"
)

// Reads the real NetworkManager on this machine and prints what the widget
// would receive. Skips when there's no system bus.
func TestLiveRead(t *testing.T) {
	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		t.Skip("no system bus:", err)
	}
	defer conn.Close()
	s := &Service{conn: conn}

	var primary dbus.ObjectPath
	get(conn.Object(nmService, nmPath), nmIface, "PrimaryConnection", &primary)
	carrier, ctype := s.physical(primary)
	t.Logf("real:  primary=%s carrier=%s ctype=%q", primary, carrier, ctype)
	t.Logf("state=%+v", s.read())

	// Stand in for a VPN/tunnel primary: any active connection whose type isn't
	// wifi/ethernet (loopback, bridge) exercises the same fallback branch.
	var actives []dbus.ObjectPath
	get(conn.Object(nmService, nmPath), nmIface, "ActiveConnections", &actives)
	for _, a := range actives {
		if t2 := s.connType(a); !isPhysical(t2) {
			c, ct := s.physical(a)
			t.Logf("tunnel-sim: primary=%s (%s) -> carrier=%s (%s)", a, t2, c, ct)
			if !isPhysical(ct) {
				t.Errorf("fallback failed to find a physical carrier under %s", t2)
			}
			return
		}
	}
	t.Skip("no non-physical active connection to simulate a tunnel with")
}
