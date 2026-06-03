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

    property int brightness:    0
    property int maxBrightness: 255

    property real percent: maxBrightness > 0 ? brightness / maxBrightness : 0

    property bool clicked: false

    function brightnessIcon() {
        if (percent < 0.33) return "󰃞"
        if (percent < 0.66) return "󰃟"
        return                     "󰃠"
    }

    Process {
        id: brightnessProcess
        command: ["bash", "-c", `
            max=$(cat /sys/class/backlight/amdgpu_bl1/max_brightness)
            echo "max:$max"
            cat /sys/class/backlight/amdgpu_bl1/brightness
            while inotifywait -q -e modify /sys/class/backlight/amdgpu_bl1/brightness 2>/dev/null; do
                cat /sys/class/backlight/amdgpu_bl1/brightness
            done
        `]
        stdout: SplitParser {
            onRead: data => {
                if (data.startsWith("max:")) {
                    root.maxBrightness = parseInt(data.slice(4))
                } else {
                    root.brightness = parseInt(data)
                }
            }
        }
        stderr: SplitParser {
            onRead: data => console.log("backlight stderr:", data)
        }
    }

    Component.onCompleted: brightnessProcess.running = true

    Row {
        id:               row
        anchors.centerIn: parent
        spacing:          4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           brightnessIcon()
            color:          Theme.textColor
            font.pixelSize: Theme.fontSize
            font.family:    Theme.nerdFont
        }

        Text {
            visible:       clicked
            anchors.verticalCenter: parent.verticalCenter
            text:           Math.round(root.percent * 100) + "%"
            color:          Qt.alpha(Theme.textColor, 0.8)
            font.pixelSize: Theme.fontSize
            font.family:    Theme.font
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const step = event.angleDelta.y > 0 ? "5%+" : "5%-"
            Quickshell.execDetached(["brightnessctl", "set", step])
        }
    }

    TapHandler {
        onTapped: root.clicked = !root.clicked
    }

    HoverHandler { 
        cursorShape: Qt.PointingHandCursor 
    }
}
