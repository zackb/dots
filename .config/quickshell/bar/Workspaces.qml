import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../"

Row {
    property color backgroundColor: Qt.alpha("#1e1e2e", 0.5)
    property color urgentColor: Qt.alpha("#f38ba8", 0.8)

    spacing: 4

    Repeater {
        model: Hyprland.workspaces.values.filter(ws => ws.id > 0)

        delegate: Rectangle {
            required property HyprlandWorkspace modelData

            property bool isActive: modelData.id === Hyprland.focusedMonitor?.activeWorkspace?.id
            property bool isUrgent: modelData.toplevels.values.filter(c => c.urgent && c.workspace?.id === modelData.id).length > 0

            width:  32
            height: 24
            radius: height / 2

            color: isUrgent ? urgentColor : backgroundColor

            Behavior on color {
                ColorAnimation { duration: 120 }
            }

            Text {
                anchors.centerIn: parent
                text:             modelData.id
                font.pixelSize:   Theme.fontSize
                font.family:      Theme.font
                color: isActive
                       ? Theme.fontColor
                       : Qt.alpha(Theme.fontColor, 0.3)
            }

            TapHandler {
                            
                onTapped: Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + modelData.id + "\" })")
            }
        }
    }
}
