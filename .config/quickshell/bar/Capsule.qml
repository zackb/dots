import QtQuick
import "../"

Rectangle {
    id: root
    color:  hovered ? Theme.capsuleBgHover : Theme.capsuleBg
    radius: height / 2

    Behavior on color {
        ColorAnimation { duration: 150 }
    }
    height: Theme.barHeight
    width:  (contentItem ? contentItem.implicitWidth : 0) + Theme.barHeight

    property Item contentItem: null
    property bool hovered: false
    property bool interactive: true

    HoverHandler {
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onHoveredChanged: root.hovered = hovered
    }

    onContentItemChanged: {
        if (contentItem) {
            contentItem.parent = root;
            contentItem.anchors.centerIn = root;
        }
    }
}
