import Quickshell
import QtQuick
import qs.backend
import qs.theme

Capsule {
    id: root

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

    contentItem: Row {
        id:               row
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
