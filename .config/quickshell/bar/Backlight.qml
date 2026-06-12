import Quickshell
import QtQuick
import qs.backend
import "../"

Capsule {
    id: root

    // brightness comes from the fenrizd backlight service
    // writing brightness is brightnessctl spawn in the WheelHandler below.
    property int brightness:    Backend.backlight.brightness
    property int maxBrightness: Backend.backlight.max

    property real percent: maxBrightness > 0 ? brightness / maxBrightness : 0

    property bool clicked: false

    function brightnessIcon() {
        if (percent < 0.33) return "󰃞"
        if (percent < 0.66) return "󰃟"
        return                     "󰃠"
    }

    contentItem: Row {
        id:               row
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
            const step = event.angleDelta.y < 0 ? "5%+" : "5%-"
            Quickshell.execDetached(["brightnessctl", "set", step])
        }
    }

    TapHandler {
        onTapped: root.clicked = !root.clicked
    }
}
