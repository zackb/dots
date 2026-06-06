import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../"

Capsule {
    id: root
    interactive: false

    property var toplevel: Hyprland.activeToplevel
    property var workspace: Hyprland.focusedWorkspace

    visible: toplevel != null && toplevel.workspace == workspace

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            // HACK: activeTopelevel IPC event is not there for new apps
            Hyprland.refreshToplevels()
            toplevel = Hyprland.activeToplevel
        }
        function onFocusedWorkspaceChanged() {
            workspace = Hyprland.focusedWorkspace
        }
    }

    contentItem: Row {
        id:              row
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
