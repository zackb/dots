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

    property bool expanded: false

    // ── Data ─────────────────────────────────────────────────────────
    property string cpu:  "0%"
    property string mem:  "0%"
    property string disk: "0%"
    property string temp: "0°"

    Process {
        id: sysProcess
        command: ["bash", "-c", `
            while true; do
                cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2)}')
                mem=$(free | awk '/Mem:/ {printf "%d", $3/$2*100}')
                disk=$(df / | awk 'NR==2 {print int($5)}')
                temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{printf "%d", $1/1000}')
                echo "$cpu $mem $disk $temp"
                sleep 3
            done
        `]
        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(" ")
                if (parts.length < 4) return
                root.cpu  = parts[0] + "%"
                root.mem  = parts[1] + "%"
                root.disk = parts[2] + "%"
                root.temp = parts[3] + "°"
            }
        }
    }
    TapHandler {
        onTapped: root.expanded = !root.expanded
    }
    HoverHandler { 
        cursorShape: Qt.PointingHandCursor 
    }

    Component.onCompleted: sysProcess.running = true

    Row {
        id:               row
        anchors.centerIn: parent
        spacing:          8

        // toggle icon
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           "󰞘"
            color:          Theme.textColor
            font.pixelSize: Theme.fontSize
            font.family:    Theme.nerdFont

        }

        // expandable section
        Item {
            anchors.verticalCenter: parent.verticalCenter
            height: Theme.barHeight
            width:  expanded ? innerRow.implicitWidth + 8 : 0
            clip:   true

            Behavior on width {
                NumberAnimation {
                    duration:  300
                    easing.type: Easing.InOutQuad
                }
            }

            Row {
                id:      innerRow
                height:  parent.height
                spacing: 8

                SysInfoChip { label: ""; value: root.cpu  }
                SysInfoChip { label: ""; value: root.mem  }
                SysInfoChip { label: "󰋊 "; value: root.disk }
                SysInfoChip { label: ""; value: root.temp }
            }
        }
    }
}
