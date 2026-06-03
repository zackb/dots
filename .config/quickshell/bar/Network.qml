import Quickshell
import Quickshell.Io
import QtQuick
import "../"

Rectangle {
    id: root
    color:  Qt.alpha("#1e1e2e", 0.5)
    radius: height / 2
    height: Theme.barHeight
    width:  row.implicitWidth + Theme.barHeight

    property string iface:    ""
    property string ssid:     ""
    property int    strength: 0
    property bool   connected: false
    property bool   ethernet: false

    property bool hovered: false
    property bool clicked: false

    function wifiIcon() {
        if (!connected)    return "󰤭"  // disconnected
        if (ethernet)      return "󰈀"  // ethernet
        if (strength < 25) return "󰤟"  // weak
        if (strength < 50) return "󰤢"  // ok
        if (strength < 75) return "󰤥"  // good
        return                    "󰤨"  // excellent
    }

    Timer {
        interval: 10000
        running:  true
        repeat:   true
        triggeredOnStart: true
        onTriggered: {
            networkProcess.running = false
            networkProcess.running = true
        }
    }

    Process {
        id: networkProcess
        command: ["bash", Qt.resolvedUrl("scripts/network.sh").toString().replace("file://", "")]
        stderr: SplitParser {
            onRead: data => console.log("network stderr:", data)
        }
        stdout: SplitParser {
            onRead: data => {
                const j = JSON.parse(data)
                root.connected = j.type !== "none"
                root.ethernet  = j.type === "ethernet"
                root.ssid      = j.ssid
                root.strength  = j.signal
            }
        }
        onRunningChanged: {
            if (!running) {
                // process done — if nothing set connected, we're disconnected
            }
        }
    }

    Row {
        id:               row
        anchors.centerIn: parent
        spacing:          4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           wifiIcon()
            color:          Theme.textColor
            font.pixelSize: Theme.fontSize
            font.family:    Theme.nerdFont
        }

        Text {
            visible: clicked && root.ssid !== ""
            anchors.verticalCenter: parent.verticalCenter
            text:           root.ssid
            color:          Qt.alpha(Theme.textColor, 0.8)
            font.pixelSize: Theme.fontSize
            font.family:    Theme.font
        }
    }

    HoverHandler { 
        onHoveredChanged: parent.hovered = hovered
        cursorShape: Qt.PointingHandCursor 
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onTapped: (eventPoint, button) => {
            if (button === Qt.RightButton) {
                Quickshell.execDetached(["hyprwat", "--wifi"])
            } else {
                root.clicked = !root.clicked
            }
        }
    }
}
