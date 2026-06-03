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
        left: 8
        right: 8
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
            }
            spacing: 6

            Updates {}
            Audio {}
            Bluetooth {}
            Network {}
            Battery {}
            Row {
                spacing: 12
                Idle {}
                Notifications {}
                Power {}
            }
        }
    }
}
