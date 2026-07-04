import Quickshell
import QtQuick
import qs.compositor
import qs.theme

Capsule {
    id: root
    interactive: false

    property real maxWidth: 220                                         // set by Bar.qml budget
    readonly property real naturalTextWidth: windowTitle.naturalWidth   // unconstrained title width

    // Compositor.activeWindow is already the focused window, so it's inherently on
    // the active workspace — no workspace-match check needed.
    visible: Compositor.activeWindow != null

    contentItem: Row {
        id:              row
        spacing:         6

        Image {
            property string appClass: Compositor.activeWindow?.appId ?? ""
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
            text:          Compositor.activeWindow?.title ?? ""
            color:         Theme.textColor
            fontFamily:    Theme.font
            fontPixelSize: Theme.fontSize
        }
    }
}
