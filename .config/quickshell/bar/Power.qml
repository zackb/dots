import Quickshell
import QtQuick
import "../"

import Quickshell.Io

Text {
    text: "󰐥"
    font {
        family: Theme.nerdFont
        pixelSize: Theme.fontSize
    }
    color: Theme.textColor

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: Quickshell.execDetached("wlogout")
    }
}
