// base for small, bar-anchored popups that are dismissed by hover
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
    // When set, the popup auto-centers horizontally under this item
    // Leave null to position manually by assigning targetX / targetY
    property var  targetItem: null
    property int  targetX: 0
    property int  targetY: 0
    // Panel never shrinks below this; content sizes it otherwise.
    property real minWidth: 0
    property int  contentPadding: 12
    property int  contentSpacing: 10
    // Exposed so manual positioners can read the resolved panel size.
    readonly property alias panelWidth:  panel.width
    readonly property alias panelHeight: panel.height
    property bool panelHovered: panelHoverHandler.hovered

    // Panel body goes here.
    default property alias content: contentCol.data

    // Window shell
    screen: barWindow ? barWindow.screen : null
    visible: false

    anchors { top: true; left: true }
    margins { top: root.targetY; left: root.targetX }

    implicitWidth:  panel.width
    implicitHeight: panel.height

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    function closeNow() {
        root.visible = false
        panel.opacity = 0
        panelSlide.y = -10
    }

    // Auto-center under targetItem on open. Uses Connections rather than an
    // onIsOpenChanged handler so call sites can still attach their own.
    Connections {
        target: root
        function onIsOpenChanged() {
            if (!root.isOpen || !root.targetItem || !root.barWindow) return
            const pos = root.targetItem.mapToItem(null, 0, 0)
            const marginTop = root.barWindow.margins ? root.barWindow.margins.top : 0
            const screenW = root.barWindow.width > 0 ? root.barWindow.width : 1920
            let x = pos.x + (root.targetItem.width / 2) - (panel.width / 2)
            if (x < 10) x = 10
            if (x + panel.width > screenW - 10) x = screenW - panel.width - 10
            root.targetX = x
            root.targetY = pos.y + marginTop + root.barWindow.height + 6
        }
    }

    Rectangle {
        id: panel
        x: 0; y: 0
        width:  Math.max(contentCol.implicitWidth + root.contentPadding * 2, root.minWidth)
        height: contentCol.implicitHeight + root.contentPadding * 2
        color:  Theme.popupBg
        radius: Theme.radius
        border.color: Theme.popupBorder
        border.width: 1

        // Slide-down on open via transform.
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

        HoverHandler { id: panelHoverHandler }

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
