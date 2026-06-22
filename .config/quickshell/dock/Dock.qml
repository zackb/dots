import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.dock

// Floating, translucent, auto-hiding app dock. Single instance (primary screen).
// Attaches to bottom/left/right per DockState.position; reveals on edge hover.
PanelWindow {
    id: root

    // tuning
    readonly property int innerPad: 8     // padding inside the dock around the icons
    readonly property int iconSpacing: 6
    readonly property int gap:  10        // floating gap between dock and screen edge
    readonly property int peek: 4         // sliver left visible when hidden (the reveal zone)

    readonly property string position: DockState.position
    readonly property bool isHorizontal: position === "bottom"

    // Resolve pinned ids -> DesktopEntries, dropping any that don't exist.
    // Touch DesktopEntries.applications so this re-resolves once the app
    // database finishes loading.
    // Each pinnedApps item is either an id string, or { id, icon } to override icon
    readonly property var apps: {
        const _ = DesktopEntries.applications.values.length
        var out = []
        const items = DockState.pinnedApps || []
        for (var i = 0; i < items.length; i++) {
            const it = items[i]
            const id = (typeof it === "string") ? it : it.id
            const e = DesktopEntries.heuristicLookup(id)
            if (e)
                out.push({ id: id, entry: e,
                           icon: (typeof it === "object" && it.icon) ? it.icon : "" })
        }
        return out
    }

    // reveal state lives in DockState so the corner tray shares it

    // window

    visible: DockState.enabled
    color: "transparent"

    WlrLayershell.layer:         WlrLayer.Top
    WlrLayershell.namespace:     "dock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        bottom: root.position === "bottom"
        left:   root.position === "left"
        right:  root.position === "right"
    }

    // Transparent headroom around the dock so name tooltips can render outside
    readonly property int tipBand:  40    // above the dock (bottom layout)
    readonly property int tipSpace: 220   // beside the dock (for tooltips)

    implicitWidth:  isHorizontal ? dock.implicitWidth + tipSpace * 2
                                 : dock.implicitWidth + gap + tipSpace
    implicitHeight: isHorizontal ? dock.implicitHeight + gap + tipBand
                                 : dock.implicitHeight

    // Only the visible dock area grabs input; the rest of the band (and the dock
    // while hidden, save the peek strip) passes clicks through to the desktop.
    mask: Region { item: dock }

    // dock body

    Rectangle {
        id: dock

        implicitWidth:  content.implicitWidth  + root.innerPad * 2
        implicitHeight: content.implicitHeight + root.innerPad * 2

        radius: Math.min(implicitWidth, implicitHeight) / 2
        color: Qt.alpha(Theme.surface, 0.55)
        antialiasing: true

        // how far to slide off-screen when hidden (leaving `peek`)
        readonly property real hideOffset:
            (root.isHorizontal ? implicitHeight : implicitWidth) + root.gap - root.peek

        // resting (revealed) top-left within the window
        readonly property real restX:
            root.position === "left"  ? root.gap
          : root.position === "right" ? root.width - root.gap - implicitWidth
          : (root.width - implicitWidth) / 2
        readonly property real restY:
            root.position === "bottom" ? root.height - root.gap - implicitHeight
          : (root.height - implicitHeight) / 2

        x: restX + (DockState.revealed ? 0
              : root.position === "left"  ? -hideOffset
              : root.position === "right" ?  hideOffset
              : 0)
        y: restY + (DockState.revealed && root.position === "bottom" ? 0
              : root.position === "bottom" ? hideOffset
              : 0)

        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        HoverHandler {
            onHoveredChanged: {
                if (hovered) DockState.reveal()
                else DockState.scheduleHide()
            }
        }

        // Horizontal layout (bottom dock)
        Row {
            id: rowLayout
            visible: root.isHorizontal
            anchors.centerIn: parent
            spacing: root.iconSpacing
            Repeater {
                model: root.isHorizontal ? root.apps : []
                delegate: DockIcon {
                    required property var modelData
                    appId: modelData.id
                    entry: modelData.entry
                    iconOverride: modelData.icon
                }
            }
        }

        // Vertical layout (left/right dock)
        Column {
            id: colLayout
            visible: !root.isHorizontal
            anchors.centerIn: parent
            spacing: root.iconSpacing
            Repeater {
                model: root.isHorizontal ? [] : root.apps
                delegate: DockIcon {
                    required property var modelData
                    appId: modelData.id
                    entry: modelData.entry
                    iconOverride: modelData.icon
                }
            }
        }

        // points the layout sizing at whichever positioner is active
        property var content: root.isHorizontal ? rowLayout : colLayout
    }
}
