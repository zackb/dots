import Quickshell
import Quickshell.Io
import QtQuick
import qs.bar
import qs.launcher
import qs.notification
import qs.bluetooth
import qs.mlb

ShellRoot {

    property bool shellVisible: true

    IpcHandler {
        target: "shell"

        function toggle() {
            shellVisible = !shellVisible
        }

        function reload() {
            Quickshell.reload(false)
        }
    }

    ControlCenter { id: controlCenter }

    Variants {
        model: Quickshell.screens
        delegate: Bar {
            required property var modelData
            screen: modelData
            controlCenterRef: controlCenter
        }
    }

    BluetoothPopup {}
    NotifPopup {}
    NotifTray {}

    Launcher {}
    ScoreWidget {
        active: shellVisible
    }

    Connections {
        target: Quickshell

        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup()
        }

        function onReloadFailed() {
            // Quickshell.inhibitReloadPopup()
        }
    }
}
