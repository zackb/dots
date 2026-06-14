import Quickshell
import QtQuick
import qs.theme
import qs.bluetooth

Capsule {
    id: bluetoothButton
    property var barWindow
    property bool menuOpen: false

    contentItem: Row {
        id:              row

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           "󰂯"
            color:          Theme.textColor
            font.pixelSize: Theme.fontSize
            font.family:    Theme.nerdFont
        }
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
