import Quickshell
import QtQuick
import qs.theme
import qs.bluetooth

Capsule {
    id: bluetoothButton
    property var barWindow

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
        onTapped: bluetoothMenu.toggleMenu(bluetoothButton)
    }

    BluetoothMenu {
        id: bluetoothMenu
        barWindow: bluetoothButton.barWindow
    }
}
