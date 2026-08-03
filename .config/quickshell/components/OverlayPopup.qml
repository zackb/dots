// Base for click-dismissed popups anchored under a bar item.
//
// The Wayland surface is a full-screen transparent overlay so a backdrop can
// catch click-outside; it stays unmapped (visible:false) while closed so it
// doesn't steal pointer focus.
//
// Subclasses declare only their content -- the panel, drop shadow, slide-in,
// click-swallowing, Escape handling and anchor math all live here. See
// AnchoredPopup for the hover-dismissed variant.
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.theme

PanelWindow {
    id: root

    // Public API
    property var  barWindow
    property bool isOpen: false
    // Bar item to align under. Leave null to position manually via targetX/targetY.
    property Item anchorItem: null
    // Center the panel on the anchor rather than left-aligning to it.
    property bool centerOnAnchor: false
    property int  targetX: 0
    property int  targetY: 0

    property int  panelWidth: 320
    property int  edgeMargin: 8       // keep-off distance from the screen edges
    property int  contentPadding: 12
    property int  contentSpacing: 8

    // Panel body goes here.
    default property alias content: contentCol.data

    // Emitted when the user clicks outside the panel or presses Escape.
    signal requestClose()

    // Bar spans the screen, so its width is the usable width; fall back to the
    // output's own width before resorting to a guess.
    readonly property real _screenW: (barWindow && barWindow.width > 0)
        ? barWindow.width
        : (screen ? screen.width : 1920)

    // Place the panel under anchorItem, clamped inside the screen edges.
    // Connections rather than onIsOpenChanged so subclasses can still attach
    // their own handler (WifiMenu triggers a scan, MprisPopup refreshes position).
    Connections {
        target: root
        function onIsOpenChanged() {
            if (!root.isOpen || !root.anchorItem) return
            const pos = root.anchorItem.mapToItem(null, 0, root.anchorItem.height)
            const marginTop = (root.barWindow && root.barWindow.margins)
                ? root.barWindow.margins.top : 0
            const x = root.centerOnAnchor
                ? pos.x + (root.anchorItem.width / 2) - (panel.width / 2)
                : pos.x
            root.targetX = Math.max(root.edgeMargin,
                Math.min(Math.round(x), root._screenW - panel.width - root.edgeMargin))
            root.targetY = marginTop + (root.barWindow ? root.barWindow.height : 0) + 6
        }
    }

    // Window shell
    screen: barWindow ? barWindow.screen : null
    visible: false

    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // Transparent backdrop: click anywhere outside the panel to close.
    MouseArea {
        anchors.fill: parent
        onClicked: root.requestClose()
        z: -1
    }

    Rectangle {
        id: panel
        x: root.targetX
        y: root.targetY
        width:  root.panelWidth
        height: contentCol.implicitHeight + root.contentPadding * 2
        // Smoothly absorb content height changes while already shown (the mpris
        // popup swapping tracks) instead of snapping. Only once open, so the
        // open transition itself isn't animated.
        Behavior on height {
            enabled: root.visible && root.isOpen
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }
        color:  Theme.popupBg
        radius: Theme.radius
        border.color: Theme.popupBorder
        border.width: 1

        // Slide-down on open via transform, so x/y stay pinned to the target.
        transform: Translate { id: panelSlide; y: -10 }

        // Drop shadow
        Rectangle {
            anchors { fill: parent; margins: -1 }
            color: "transparent"
            border.color: Qt.rgba(0, 0, 0, 0.4)
            border.width: 1
            radius: Theme.radius + 1
            z: -1
        }

        // Swallow clicks so they don't reach the backdrop and close the popup.
        MouseArea { anchors.fill: parent }

        Shortcut {
            sequence: "Escape"
            enabled: root.isOpen
            onActivated: root.requestClose()
        }

        ColumnLayout {
            id: contentCol
            anchors {
                top: parent.top; left: parent.left; right: parent.right
                topMargin:   root.contentPadding
                leftMargin:  root.contentPadding
                rightMargin: root.contentPadding
            }
            spacing: root.contentSpacing
        }

        states: [
            State { name: "open";   when: root.isOpen;  PropertyChanges { target: panel; opacity: 1.0 } PropertyChanges { target: panelSlide; y: 0   } },
            State { name: "closed"; when: !root.isOpen; PropertyChanges { target: panel; opacity: 0.0 } PropertyChanges { target: panelSlide; y: -10 } }
        ]
        transitions: [
            Transition {
                from: "closed"; to: "open"
                SequentialAnimation {
                    ScriptAction { script: root.visible = true }
                    ParallelAnimation {
                        NumberAnimation { target: panel;      property: "opacity"; duration: 180; easing.type: Easing.OutQuad }
                        NumberAnimation { target: panelSlide; property: "y";       duration: 180; easing.type: Easing.OutQuad }
                    }
                }
            },
            Transition {
                from: "open"; to: "closed"
                SequentialAnimation {
                    ParallelAnimation {
                        NumberAnimation { target: panel;      property: "opacity"; duration: 150; easing.type: Easing.OutQuad }
                        NumberAnimation { target: panelSlide; property: "y";       duration: 150; easing.type: Easing.OutQuad }
                    }
                    ScriptAction { script: root.visible = false }
                }
            }
        ]
    }
}
