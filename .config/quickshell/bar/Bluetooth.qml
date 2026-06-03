import Quickshell
import QtQuick
import "../"
import "../bluetooth"

Rectangle {
    color:  Qt.alpha("#1e1e2e", 0.5)
    radius: height / 2
    height: Theme.barHeight
    width:  row.implicitWidth + Theme.barHeight
    Row {
        id:              row
        anchors.centerIn: parent

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           "󰂯"
            color:          Theme.textColor
            font.pixelSize: Theme.fontSize
            font.family:    Theme.nerdFont

        }

    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: Quickshell.execDetached(["qs", "ipc", "call", "bluetooth", "toggle"])
    }

}
