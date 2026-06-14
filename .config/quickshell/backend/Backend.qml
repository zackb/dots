pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

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

    // screen brightness (sysfs backlight)
    property var backlight: ({ brightness: 0, max: 1 })

    // upcoming calendar events (vdirsyncer .ics store), soonest first
    property var calendarState: ({ upcoming: [] })

    // address book (vdirsyncer .vcf store); launcher filters this list
    property var contacts: []

    // cpu / memory / disk / temperature
    property var sysinfo: ({
        cpuModel: "", overallCpu: 0, memPercent: 0, diskPercent: 0, tempC: 0,
        cpuCores: [], memUsedMB: 0, memTotalMB: 1, memBuffMB: 0, memAvailMB: 0,
        diskUsedMB: 0, diskTotalMB: 1, diskAvailMB: 0
    })

    // generic hook for event-driven consumers
    signal serviceEvent(string service, var data)

    // true while the daemon process is up
    readonly property bool running: daemon.running

    Process {
        id: daemon
        running: true
        command: [Quickshell.shellPath("backend/fenrizd")]

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
                else if (msg.service === "sysinfo")
                    root.sysinfo = msg.data
                else if (msg.service === "backlight")
                    root.backlight = msg.data
                else if (msg.service === "calendar")
                    root.calendarState = msg.data
                else if (msg.service === "contacts")
                    root.contacts = msg.data
                root.serviceEvent(msg.service, msg.data)
            }
        }

        // If the daemon dies, never leave the shell believing something is still
        // inhibiting (that would wedge idle off). Reset, then relaunch shortly.
        onExited: (code, status) => {
            root._screensaver = ({ inhibited: false, count: 0, inhibitors: [] })
            root.mlbState = ({ active: false, class: "mlb-idle" })
            root.networkState = ({ type: "none", ssid: "", signal: 0, iface: "" })
            root.calendarState = ({ upcoming: [] })
            root.contacts = []
            relaunch.start()
        }
    }

    Timer {
        id: relaunch
        interval: 2000
        onTriggered: daemon.running = true
    }
}
