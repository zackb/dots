import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.theme

Text {
    id: root
    property bool inhibiting: false

    text:           inhibiting ? "" : ""

    color:          Theme.textColor
    font.pixelSize: Theme.fontSize + 3
    font.family:    Theme.nerdFont

    IdleInhibitor {
        // window must be non-null or the inhibitor is never created
        window:  root.QsWindow.window
        enabled: inhibiting
    }

    TapHandler {
        onTapped: inhibiting = !inhibiting
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
