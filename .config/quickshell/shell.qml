import Quickshell
import Quickshell.Io
import QtQuick
import qs.bar
import qs.bar.controlcenter
import qs.launcher
import qs.dock
import qs.tray
import qs.notification
import qs.bluetooth
import qs.mlb
import qs.calendar
import qs.osd
import qs.wallpaper
import qs.lock
import qs.polkit
import qs.theme

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

        function reloadColors() {
            Theme.reloadColors()
        }
    }

    LazyLoader { active: Theme.wallpaperEnabled; component: Component { Wallpaper {} } }

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
    LazyLoader { active: Theme.notificationsEnabled; component: Component { NotifPopup {} } }
    LazyLoader { active: Theme.notificationsEnabled; component: Component { NotifTray {} } }

    Osd {}

    LazyLoader { active: Theme.idleLockEnabled; component: Component { IdleDaemon {} } }

    LazyLoader { active: Theme.polkitEnabled;   component: Component { Polkit {} } }

    Launcher {}
    Dock {}
    TrayDock {}
    ScoreWidget {
        active: shellVisible
    }
    EventsWidget {
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
