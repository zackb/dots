import Quickshell
import Quickshell.Hyprland
import QtQuick

Row {
    property color activeColor: Qt.rgba(0.9, 0.9, 0.9, 0.9)
    property color occupiedColor: Qt.rgba(0.5, 0.5, 0.6, 0.6)
    property color emptyColor: Qt.rgba(0.3, 0.3, 0.3, 0.3)

    spacing: 4

    Repeater {
        model: Hyprland.workspaces.values.filter(ws => ws.id > 0)

        delegate: Rectangle {
            required property HyprlandWorkspace modelData

            property bool isActive: modelData.id === Hyprland.focusedMonitor?.activeWorkspace?.id

            width:  32
            height: 24
            radius: height / 2

            // Active = bright, occupied = dim, empty = faint
            color: isActive ? activeColor
                   : modelData.toplevels.values.filter(c => c.workspace?.id === modelData.id).length > 0
                     ? occupiedColor
                     : emptyColor

            Behavior on color {
                ColorAnimation { duration: 120 }
            }

            Text {
                anchors.centerIn: parent
                text:             modelData.id
                font.pixelSize:   16
                font.family:      "Cantarell"
                color: isActive
                       ? "#111"
                       : "#aaa"
            }

            TapHandler {
                            
                onTapped: Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + modelData.id + "\" })")
            }
        }
    }
}
