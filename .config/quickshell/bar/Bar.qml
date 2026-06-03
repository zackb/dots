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
        right: 4
    }

    WlrLayershell.layer:     WlrLayer.Top
    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.exclusionMode: ExclusionMode.Exclusive  // pushes windows down

    implicitHeight: 24

    color:  "transparent"

    Rectangle {
        anchors.fill: parent
        // color:        Qt.rgba(0.05, 0.05, 0.08, 0.75)
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
            BarSeparator {}
            ActiveWindow {}
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
                rightMargin:    8
            }
            spacing: 4

            Updates {}
            Audio {}
            Bluetooth {}
            Network {}
            Battery {}
            Power {}
        }
    }
}
