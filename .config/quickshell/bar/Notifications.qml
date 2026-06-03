import Quickshell
import Quickshell.Io
import QtQuick
import "../"

Text {
    id: root

    property bool hasNotifications: false
    property bool dnd: false

    text: dnd
        ? (hasNotifications ? "" : "")
        : (hasNotifications ? "" : "")

    color:          Theme.textColor
    font.pixelSize: Theme.fontSize
    font.family:    Theme.nerdFont

    Process {
        id: swayncProcess
        command: ["swaync-client", "-swb"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    console.log("swaync output:", data)
                    const j = JSON.parse(data)
                    root.hasNotifications = j.class?.includes("notification") ?? false
                    root.dnd              = j.class?.includes("dnd") ?? false
                } catch(e) {
                    console.log("swaync parse error:", e, data)
                }
            }
        }
    }

    Timer {
        interval: 5000
        running:  true
        repeat:   true
        triggeredOnStart: true
        onTriggered: {
            swayncProcess.running = false
            swayncProcess.running = true
        }
    }

    HoverHandler { cursorShape: Qt.PointingHandCursor }

    TapHandler {
        onTapped: Quickshell.execDetached(["swaync-client", "-t", "-sw"])
    }
}
