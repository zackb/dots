import QtQuick
import qs.theme

Item {
    id: root

    property real from:  0
    property real to:    1
    property real value: 0

    property color trackColor: Theme.primary

    signal moved(real newValue)

    implicitHeight: 24

    readonly property real _pos: to > from
        ? Math.max(0, Math.min(1, (value - from) / (to - from)))
        : 0

    // Track background
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width; height: 4; radius: 2
        color: Theme.surface_container_high

        Rectangle {
            width: root._pos * parent.width
            height: parent.height; radius: parent.radius
            color: root.trackColor
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    // Handle
    Rectangle {
        x: root._pos * (parent.width - width)
        anchors.verticalCenter: parent.verticalCenter
        width: 18; height: 18; radius: 9
        color: Theme.surface
        border.color: root.trackColor
        border.width: 2
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        function valueAt(mx) {
            return root.from + Math.max(0, Math.min(1, mx / root.width)) * (root.to - root.from)
        }

        onPressed:          root.moved(valueAt(mouseX))
        onPositionChanged:  if (pressed) root.moved(valueAt(mouseX))
    }
}
