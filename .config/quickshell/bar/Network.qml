import Quickshell
import QtQuick
import qs.backend
import qs.theme

Capsule {
    id: root

    property var barWindow
    property bool menuOpen: false

    readonly property var net: Backend.networkState
    property string iface:    net.iface || ""
    property string ssid:     net.ssid || ""
    property int    strength: net.signal || 0
    property bool   connected: net.type !== "none"
    property bool   ethernet:  net.type === "ethernet"

    property bool clicked: false

    function wifiIcon() {
        if (!connected)    return "󰤭"  // disconnected
        if (ethernet)      return "󰈀"  // ethernet
        if (strength < 25) return "󰤟"  // weak
        if (strength < 50) return "󰤢"  // ok
        if (strength < 75) return "󰤥"  // good
        return                    "󰤨"  // excellent
    }

    contentItem: IconLabel {
        glyph:     root.wifiIcon()
        label:     root.ssid
        showLabel: root.clicked && root.ssid !== ""
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onTapped: (eventPoint, button) => {
            if (button === Qt.RightButton) {
                root.menuOpen = !root.menuOpen
            } else {
                root.clicked = !root.clicked
            }
        }
    }

    WifiMenu {
        barWindow:  root.barWindow
        anchorItem: root
        isOpen:     root.menuOpen
        onRequestClose: root.menuOpen = false
    }
}
