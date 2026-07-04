import Quickshell
import QtQuick
import qs.compositor
import qs.theme

Row {
    spacing: 4

    Repeater {
        model: Compositor.workspaces

        delegate: Rectangle {
            required property var modelData

            property bool isActive: modelData.focused
            property bool isUrgent: modelData.urgent

            property bool wsHovered: false

            width:  32
            height: 24
            radius: height / 2

            color: isUrgent ? Qt.alpha(Theme.critical, 0.8)
                             : wsHovered ? Theme.capsuleBgHover : Theme.capsuleBg

            Behavior on color {
                ColorAnimation { duration: 150 }
            }

            Text {
                anchors.centerIn: parent
                text:             modelData.id
                font.pixelSize:   Theme.fontSize
                font.family:      Theme.font
                color: isActive
                       ? Theme.textColor
                       : Qt.alpha(Theme.textColor, 0.3)
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: parent.wsHovered = hovered
            }

            TapHandler {
                onTapped: Compositor.focusWorkspace(modelData.id)
            }
        }
    }
}
