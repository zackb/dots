import Quickshell
import QtQuick
import "../"

Text {
    property var ccRef: null

    text:  "󰒓"
    font { 
        family: Theme.nerdFont
        pixelSize: Theme.fontSize + 3
    }
    color: Theme.textColor

    HoverHandler { cursorShape: Qt.PointingHandCursor }

    TapHandler {
        onTapped: {
            if (ccRef) ccRef.isOpen = !ccRef.isOpen
        }
    }
}
