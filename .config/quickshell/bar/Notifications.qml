import Quickshell
import Quickshell.Io
import QtQuick
import qs.notification
import "../"

Text {
    id: root

    property bool hasNotifications: NotifServer.history.count > 0
    property bool dnd: false

    text: dnd
        ? (hasNotifications ? "" : "")
        : (hasNotifications ? "" : "")

    color: Theme.textColor
    font.pixelSize: Theme.fontSize
    font.family: Theme.nerdFont

    HoverHandler { cursorShape: Qt.PointingHandCursor }

    TapHandler {
        onTapped: {
            NotifServer.trayOpen = !NotifServer.trayOpen
        }
    }
}
