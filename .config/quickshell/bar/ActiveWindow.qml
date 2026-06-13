import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs.theme

Capsule {
    id: root
    interactive: false

    property var toplevel: Hyprland.activeToplevel
    property var workspace: Hyprland.focusedWorkspace
    property real maxWidth: 220                                         // set by Bar.qml budget
    readonly property real naturalTextWidth: windowTitle.naturalWidth   // unconstrained title width

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

        Marquee {
            id: windowTitle
            anchors.verticalCenter: parent.verticalCenter
            maxWidth:      root.maxWidth
            hovered:       root.hovered
            text:          Hyprland.activeToplevel?.title ?? ""
            color:         Theme.textColor
            fontFamily:    Theme.font
            fontPixelSize: Theme.fontSize
        }
    }
}
