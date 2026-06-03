import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

PanelWindow {
    id: root

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
    WlrLayershell.exclusionMode: ExclusionMode.Exclusive  // pushes windows down

    implicitHeight: 24

    color:  "transparent"

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
        }

        // ── Center ────────────────────────────────────────────────────
        Row {
            anchors.centerIn: parent
            spacing: 8

            Clock {}
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
            Bluetooth {}
            Backlight {}
            Network {}
            Battery {}
            SysInfo {}
            Row {
                spacing: 12
                Idle {}
                Notifications {}
                Power {}
            }
        }
    }
}
