import Quickshell
import Quickshell.Hyprland
import QtQuick

Rectangle {
    color:  Qt.rgba(0.5, 0.5, 0.6, 0.6)
    radius: height / 2
    width:  windowTitle.implicitWidth + 24
    height: 24

    // TODO
    Image {
        property string appClass: Hyprland.activeToplevel?.appId ?? ""
        property DesktopEntry entry: DesktopEntries.byId(appClass)

        source: entry?.icon ?? ""
        width:  16
        height: 16
    }

    Text {
        id: windowTitle
        property string title: Hyprland.activeToplevel?.title ?? ""
        anchors.centerIn: parent
        text:             title.length > 40 ? title.slice(0, 40) + "…" : title
        color:            "#ddd"
        font.pixelSize:   16
        font.family:      "Cantarell"
    }
}
