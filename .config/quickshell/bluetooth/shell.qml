// Run with: quickshell -p ~/.config/quickshell/bluetooth
//
// Toggle popup:  qs -c bluetooth ipc call bluetooth toggle

import Quickshell
import QtQuick

ShellRoot {
    BluetoothPopup {}
}
