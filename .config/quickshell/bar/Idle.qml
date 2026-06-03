import Quickshell
import Quickshell.Wayland
import QtQuick
import "../"

Text {
    property bool inhibiting: false

    text:           inhibiting ? "" : ""

    color:          Theme.textColor
    font.pixelSize: Theme.fontSize
    font.family:    Theme.nerdFont

    IdleInhibitor {
        enabled: inhibiting
    }

    TapHandler {
        onTapped: inhibiting = !inhibiting
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
