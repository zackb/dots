import Quickshell
import QtQuick
import qs.backend
import qs.theme

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

    contentItem: IconLabel {
        glyph:     root.brightnessIcon()
        label:     Math.round(root.percent * 100) + "%"
        showLabel: root.clicked
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const step = event.angleDelta.y < 0 ? "5%+" : "5%-"
            Backend.setBrightness(step)
        }
    }

    TapHandler {
        onTapped: root.clicked = !root.clicked
    }
}
