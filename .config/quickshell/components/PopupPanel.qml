// The visual body shared by every popup: themed surface, drop shadow, a
// click-swallowing area so the backdrop behind doesn't see the press, and the
// fade + slide that runs when `open` flips.
//
// Positioning and sizing stay with the caller -- this owns appearance and the
// open/close transition only. `slideX`/`slideY` are the closed-state offsets, so
// a menu that rises sets a positive slideY and a right-hand drawer sets slideX.
//
// It maps and unmaps the containing window itself: the surface must be gone
// while closed or it keeps stealing Wayland pointer focus, but it has to outlive
// the fade-out, which only the transition knows the end of. The window is passed
// in rather than found via QsWindow.window, which is null precisely when the
// surface is unmapped -- the state every open transition starts from.
import Quickshell
import QtQuick
import qs.theme

Rectangle {
    id: panel

    property bool open: false
    property real slideX: 0
    property real slideY: -10

    // The PanelWindow to map/unmap around the transition.
    property var surface: null

    default property alias content: inner.data

    color: Theme.popupBg
    radius: Theme.radius
    border.color: Theme.popupBorder
    border.width: 1

    transform: Translate { id: slide; x: panel.slideX; y: panel.slideY }

    Rectangle {
        anchors { fill: parent; margins: -1 }
        color: "transparent"
        border.color: Qt.rgba(0, 0, 0, 0.4)
        border.width: 1
        radius: Theme.radius + 1
        z: -1
    }

    MouseArea { anchors.fill: parent }

    Item {
        id: inner
        anchors.fill: parent
    }

    states: [
        State {
            name: "open"; when: panel.open
            PropertyChanges { target: panel; opacity: 1.0 }
            PropertyChanges { target: slide; x: 0; y: 0 }
        },
        State {
            name: "closed"; when: !panel.open
            PropertyChanges { target: panel; opacity: 0.0 }
            PropertyChanges { target: slide; x: panel.slideX; y: panel.slideY }
        }
    ]
    transitions: [
        Transition {
            from: "closed"; to: "open"
            SequentialAnimation {
                ScriptAction { script: if (panel.surface) panel.surface.visible = true }
                ParallelAnimation {
                    NumberAnimation { target: panel; property: "opacity"; duration: 180; easing.type: Easing.OutQuad }
                    NumberAnimation { target: slide; property: "x";       duration: 180; easing.type: Easing.OutQuad }
                    NumberAnimation { target: slide; property: "y";       duration: 180; easing.type: Easing.OutQuad }
                }
            }
        },
        Transition {
            from: "open"; to: "closed"
            SequentialAnimation {
                ParallelAnimation {
                    NumberAnimation { target: panel; property: "opacity"; duration: 150; easing.type: Easing.OutQuad }
                    NumberAnimation { target: slide; property: "x";       duration: 150; easing.type: Easing.OutQuad }
                    NumberAnimation { target: slide; property: "y";       duration: 150; easing.type: Easing.OutQuad }
                }
                ScriptAction { script: if (panel.surface) panel.surface.visible = false }
            }
        }
    ]
}
