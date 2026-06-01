import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../"

Rectangle {
    color:  Qt.alpha("#1e1e2e", 0.5)
    radius: height / 2
    height: 24
    width:  row.implicitWidth + 24

    Connections {
        target: Hyprland
        onActiveToplevelChanged: {
            // HACK: activeTopelevel IPC event is not there for new apps
            Hyprland.refreshToplevels()
        }
    }

    Row {
        id:              row
        anchors.centerIn: parent
        spacing:         6

        Image {
            property string appClass: Hyprland.activeToplevel?.lastIpcObject?.class ?? ""
            property DesktopEntry entry: DesktopEntries.heuristicLookup(appClass)
            anchors.verticalCenter: parent.verticalCenter
            source: entry ? "image://icon/" + entry.icon : ""
            width:  16
            height: 16
        }

        Text {
            id: windowTitle
            property string title: Hyprland.activeToplevel?.title ?? ""
            anchors.verticalCenter: parent.verticalCenter
            text:           title.length > 40 ? title.slice(0, 40) + "…" : title
            color:          Theme.textColor
            font.pixelSize: Theme.fontSize
            font.family:    Theme.font
        }
    }
}
