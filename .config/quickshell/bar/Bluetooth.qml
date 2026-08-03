import Quickshell
import QtQuick
import qs.backend
import qs.theme
import qs.bluetooth

Capsule {
    id: bluetoothButton
    property var barWindow
    property bool menuOpen: false

    // Lower of the two AirPods buds, or -1 when unknown/disconnected.
    readonly property int airpodsPct: {
        const a = Backend.airpods
        if (!a || !a.connected) return -1
        const vals = [a.left, a.right].filter(v => v >= 0)
        return vals.length ? Math.min(...vals) : -1
    }

    contentItem: IconLabel {
        glyph:     "󰂯"
        label:     bluetoothButton.airpodsPct + "%"
        showLabel: bluetoothButton.airpodsPct >= 0
        labelSize: Theme.font_size_sm
    }

    TapHandler {
        onTapped: bluetoothButton.menuOpen = !bluetoothButton.menuOpen
    }

    BluetoothMenu {
        id: bluetoothMenu
        barWindow:  bluetoothButton.barWindow
        anchorItem: bluetoothButton
        isOpen:     bluetoothButton.menuOpen
        onRequestClose: bluetoothButton.menuOpen = false
    }
}
