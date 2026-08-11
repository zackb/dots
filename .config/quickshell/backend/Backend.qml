pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.theme

// Front-end to the Fenriz backend daemon (backend/fenrizd). The daemon owns DBus
// services Quickshell can't host and streams newline-delimited JSON events on
// stdout; this singleton launches it, routes those events, and exposes the
// state to the rest of the shell.
//
// each event is {"service": "...", "data": {...}}.
Singleton {
    id: root

    // screensaver / idle-inhibit (org.freedesktop + org.gnome ScreenSaver)
    readonly property bool screensaverInhibited: _screensaver.inhibited === true
    readonly property var  screensaverInhibitors: _screensaver.inhibitors || []
    property var _screensaver: ({ inhibited: false, count: 0, inhibitors: [] })

    // mlb scoreboard for the configured team's game today
    property var mlbState: ({ active: false, class: "mlb-idle" })

    // primary network connection (NetworkManager)
    property var networkState: ({ type: "none", ssid: "", signal: 0, iface: "" })

    // wifi scan results + radio state (nmcli via fenrizd); driven by the popup
    property var wifiState: ({ enabled: true, connecting: false, error: "", networks: [] })

    // screen brightness (sysfs backlight)
    property var backlight: ({ device: "", brightness: 0, max: 1 })

    // Write the panel backlight. Targets the device the daemon watches so a
    // write is always reflected by the reading that comes back; Theme's name is
    // only a fallback for before the first event arrives.
    // `value` is anything brightnessctl accepts -- "5%+", "5%-", "1200".
    function setBrightness(value) {
        const dev = root.backlight.device || Theme.backlightDevice
        Quickshell.execDetached(["brightnessctl", "-d", dev, "-q", "set", String(value)])
    }

    // upcoming calendar events (vdirsyncer .ics store), soonest first
    property var calendarState: ({ upcoming: [] })

    // address book (vdirsyncer .vcf store); launcher filters this list
    property var contacts: []

    // clipboard history (fenrizd captures via wl-paste, restores via wl-copy)
    property var clipboard: ({ entries: [] })

    // AirPods battery (Apple BLE proximity beacons via fenrizd); -1 = hidden
    property var airpods: ({ connected: false, address: "", left: -1, right: -1, case: -1 })

    // cpu / memory / disk / temperature
    property var sysinfo: ({
        cpuModel: "", overallCpu: 0, memPercent: 0, diskPercent: 0, tempC: 0,
        cpuCores: [], memUsedMB: 0, memTotalMB: 1, memBuffMB: 0, memAvailMB: 0,
        diskUsedMB: 0, diskTotalMB: 1, diskAvailMB: 0, acOnline: false
    })

    // generic hook for event-driven consumers
    signal serviceEvent(string service, var data)

    // true while the daemon process is up
    readonly property bool running: daemon.running

    // Send a command down the daemon's stdin (NDJSON). The inbound half of the
    // protocol; routed to a service's Commander (e.g. clipboard copy/delete/wipe).
    function command(svc, verb, args) {
        daemon.write(JSON.stringify({ service: svc, command: verb, args: args || ({}) }) + "\n")
    }

    Process {
        id: daemon
        running: true
        command: [Quickshell.shellPath("backend/fenrizd")].concat(
            Theme.disabledServices.length > 0
                ? ["-disable", Theme.disabledServices.join(",")]
                : [])
        stdinEnabled: true

        stdout: SplitParser {
            onRead: line => {
                let msg
                try { msg = JSON.parse(line) } catch (e) { return }
                if (!msg || !msg.service)
                    return
                if (msg.service === "screensaver")
                    root._screensaver = msg.data
                else if (msg.service === "mlb")
                    root.mlbState = msg.data
                else if (msg.service === "network")
                    root.networkState = msg.data
                else if (msg.service === "wifi")
                    root.wifiState = msg.data
                else if (msg.service === "sysinfo")
                    root.sysinfo = msg.data
                else if (msg.service === "backlight")
                    root.backlight = msg.data
                else if (msg.service === "calendar")
                    root.calendarState = msg.data
                else if (msg.service === "contacts")
                    root.contacts = msg.data
                else if (msg.service === "clipboard")
                    root.clipboard = msg.data
                else if (msg.service === "airpods")
                    root.airpods = msg.data
                root.serviceEvent(msg.service, msg.data)
            }
        }

        // If the daemon dies, never leave the shell believing something is still
        // inhibiting (that would wedge idle off). Reset, then relaunch on a
        // backoff -- a daemon that can't start at all (missing binary after a
        // `make clean`) would otherwise respawn every 2s forever.
        onExited: (code, status) => {
            root._screensaver = ({ inhibited: false, count: 0, inhibitors: [] })
            root.mlbState = ({ active: false, class: "mlb-idle" })
            root.networkState = ({ type: "none", ssid: "", signal: 0, iface: "" })
            root.wifiState = ({ enabled: true, connecting: false, error: "", networks: [] })
            root.calendarState = ({ upcoming: [] })
            root.contacts = []
            root.clipboard = ({ entries: [] })
            root.airpods = ({ connected: false, address: "", left: -1, right: -1, case: -1 })
            root.backlight = ({ device: "", brightness: 0, max: 1 })

            // A run that lasted a while is a crash, not a broken build: restart
            // promptly and reset the backoff.
            if (Date.now() - root._startedAt > 60000)
                root._relaunchDelay = 2000
            relaunch.interval = root._relaunchDelay
            root._relaunchDelay = Math.min(root._relaunchDelay * 2, 60000)
            relaunch.start()
        }

        onRunningChanged: if (running) root._startedAt = Date.now()
    }

    property real _startedAt: Date.now()
    property int  _relaunchDelay: 2000

    Timer {
        id: relaunch
        interval: 2000
        onTriggered: daemon.running = true
    }
}
