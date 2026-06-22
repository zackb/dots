import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import qs.theme
import qs.dock

// Floating system-tray capsule pinned to the bottom-right corner. Hidden by
// default; shares DockState.revealed so it slides in/out together with the dock,
// and its own hover keeps both revealed. Single instance (primary screen).
PanelWindow {
    id: root

    readonly property int innerPad: 8     // padding inside the capsule around the icons
    readonly property int gap:  10        // floating gap from the screen edges
    readonly property int peek: 4         // sliver left visible when hidden (reveal zone)

    visible: DockState.enabled && SystemTray.items.values.length > 0
    color: "transparent"

    WlrLayershell.layer:         WlrLayer.Top
    WlrLayershell.namespace:     "traydock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors { bottom: true; right: true }

    implicitWidth:  capsule.implicitWidth + gap * 2
    implicitHeight: capsule.implicitHeight + gap

    // Only the capsule (and its peek strip when hidden) grabs input.
    mask: Region { item: capsule }

    Rectangle {
        id: capsule

        implicitWidth:  tray.implicitWidth  + root.innerPad * 2
        implicitHeight: tray.implicitHeight + root.innerPad * 2

        radius: Math.min(implicitWidth, implicitHeight) / 2
        color: Qt.alpha(Theme.surface, 0.55)
        antialiasing: true

        // how far to slide down off-screen when hidden (leaving `peek`)
        readonly property real hideOffset: implicitHeight + root.gap - root.peek

        // resting (revealed) top-left: gap from the right and bottom edges
        readonly property real restX: root.width  - root.gap - implicitWidth
        readonly property real restY: root.height - root.gap - implicitHeight

        x: restX
        y: restY + (DockState.revealed ? 0 : hideOffset)

        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        HoverHandler {
            onHoveredChanged: {
                if (hovered) DockState.reveal()
                else DockState.scheduleHide()
            }
        }

        Tray {
            id: tray
            anchors.centerIn: parent
            barWindow: root
        }
    }
}
