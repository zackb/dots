import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.bar.clock
import qs.bar.sysinfo
import qs.bar.mpris

PanelWindow {
    id: root
    property var controlCenterRef: null
    Component.onCompleted: {
        if (controlCenterRef && !controlCenterRef.barWindow)
            controlCenterRef.barWindow = root
    }

    anchors {
        top:   true
        left:  true
        right: true
    }
    margins {
        top: 4
        bottom: 2
    }

    WlrLayershell.layer:     WlrLayer.Bottom
    WlrLayershell.namespace: "zbar"

    implicitHeight: 24

    color:  "transparent"
    onScreenChanged: {
        color = "transparent"
    }

    Rectangle {
        anchors.fill: parent
        color:        Qt.rgba(0.0, 0.0, 0.0, 0.0)

        // ── Left ──────────────────────────────────────────────────────
        Row {
            id:               leftSection
            anchors {
                left:           parent.left
                verticalCenter: parent.verticalCenter
                leftMargin:     8
            }
            spacing: 4

            Workspaces {}
            BarSeparator {
                visible: activeWindow.visible
            }
            ActiveWindow {
                id: activeWindow
            }
            BarSeparator {
                visible: nowPlaying.visible
            }
            Mpris {
                id: nowPlaying
                barWindow: root
            }
        }

        // ── Center ────────────────────────────────────────────────────
        Row {
            anchors.centerIn: parent
            spacing: 8

            Clock { barWindow: root }
        }

        // ── Right ─────────────────────────────────────────────────────
        Row {
            id: rightSection
            anchors {
                right:          parent.right
                verticalCenter: parent.verticalCenter
                rightMargin:    18
            }
            spacing: 6

            Updates {}
            Audio {}
            Bluetooth {
                barWindow: root
            }
            Backlight {}
            Network {}
            Battery {}
            SysInfo {
                barWindow: root
            }
            Row {
                spacing: 12
                Idle {}
                Notifications {}
                Power { ccRef: root.controlCenterRef }
            }
        }
    }
}
