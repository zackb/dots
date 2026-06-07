import Quickshell
import Quickshell.Io
import QtQuick
import "../"

Capsule {
    id: root

    property int  percentage: 0
    property bool charging:   false
    property bool clicked: false

    function batteryIcon() {
        if (charging) return "󰂄"
        if (percentage < 10) return "󰂎"
        if (percentage < 20) return "󰁺"
        if (percentage < 30) return "󰁻"
        if (percentage < 40) return "󰁼"
        if (percentage < 50) return "󰁽"
        if (percentage < 60) return "󰁾"
        if (percentage < 70) return "󰁿"
        if (percentage < 80) return "󰂀"
        if (percentage < 90) return "󰂁"
        return "󰂂"
    }

    Process {
        id: batteryProcess
        command: ["bash", "-c", "echo $(cat /sys/class/power_supply/BAT1/capacity) $(cat /sys/class/power_supply/ACAD/online)"]
        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(" ")
                root.percentage = parseInt(parts[0]) || 0
                root.charging   = parts[1] === "1"
            }
        }
    }

    Timer {
        interval: 30000
        running:  true
        repeat:   true
        triggeredOnStart: true
        onTriggered: {
            batteryProcess.running = false
            batteryProcess.running = true
        }
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onTapped: (eventPoint, button) => {
            if (button === Qt.RightButton) {
                Quickshell.execDetached(["bash", Qt.resolvedUrl("scripts/battery.sh").toString().replace("file://", "")])
            } else {
                root.clicked = !root.clicked
            }
        }
    }

    contentItem: Row {
        id:               row
        spacing:          4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           batteryIcon()
            color:          root.percentage < 20 ? Theme.battery_low : Theme.textColor
            font.pixelSize: Theme.fontSize
            font.family:    Theme.nerdFont
        }

        Text {
            visible: clicked
            anchors.verticalCenter: parent.verticalCenter
            text:           Math.round(root.percentage ?? 0) + "%"
            color:          Qt.alpha(Theme.textColor, 0.8)
            font.pixelSize: Theme.fontSize
            font.family:    Theme.font
        }
    }
}
