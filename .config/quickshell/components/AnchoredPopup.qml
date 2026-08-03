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

    // Drop the surface without waiting for the fade, so one hovered chip can
    // hand over to another instantly. Callers clear isOpen straight after.
    function closeNow() {
        root.visible = false
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

    PopupPanel {
        id: panel
        x: 0; y: 0
        width:  Math.max(contentCol.implicitWidth + root.contentPadding * 2, root.minWidth)
        height: contentCol.implicitHeight + root.contentPadding * 2
        surface: root
        open: root.isOpen

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
    }
}
