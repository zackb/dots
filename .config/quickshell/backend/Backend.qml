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
                root.serviceEvent(msg.service, msg.data)
            }
        }

        // If the daemon dies, never leave the shell believing something is still
        // inhibiting (that would wedge idle off). Reset, then relaunch shortly.
        onExited: (code, status) => {
            root._screensaver = ({ inhibited: false, count: 0, inhibitors: [] })
            relaunch.start()
        }
    }

    Timer {
        id: relaunch
        interval: 2000
        onTriggered: daemon.running = true
    }
}
