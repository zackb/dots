// Themed context menu for a system-tray item. The item's DBus menu is read
// via QsMenuOpener; submenus expand inline. Click-dismissed like BluetoothMenu.
import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.theme

PanelWindow {
    id: root

    property var  barWindow
    property var  trayItem
    property bool isOpen: false
    property int  targetX: 0
    property int  targetY: 0

    readonly property int menuWidth: 240

    function openAt(item) {
        var pos       = item.mapToItem(null, 0, 0)
        var marginTop = (barWindow && barWindow.margins) ? barWindow.margins.top : 0
        var screenW   = barWindow ? barWindow.width : 1920

        var x = pos.x + (item.width / 2) - (menuWidth / 2)
        if (x < 10) x = 10
        if (x + menuWidth > screenW - 10) x = screenW - menuWidth - 10

        targetX = x
        targetY = pos.y + marginTop + item.height + 6
        isOpen  = true
    }

    screen:  barWindow ? barWindow.screen : null
    visible: false

    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode:               ExclusionMode.Ignore
    color: "transparent"

    QsMenuOpener {
        id: opener
        menu: (root.trayItem && root.isOpen) ? root.trayItem.menu : null
    }

    // Backdrop: any outside click dismisses.
    MouseArea {
        anchors.fill: parent
        onClicked: root.isOpen = false
        z: -1
    }

    Rectangle {
        id: panel
        x: root.targetX
        y: root.targetY
        width:  root.menuWidth
        height: col.implicitHeight + 12
        color:  Theme.popupBg
        radius: Theme.radius
        border.color: Theme.popupBorder
        border.width: 1

        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            color: "transparent"
            border.color: Qt.rgba(0, 0, 0, 0.4)
            border.width: 1
            radius: Theme.radius + 1
            z: -1
        }

        // Swallow clicks on the panel itself so the backdrop doesn't close it.
        MouseArea { anchors.fill: parent }

        Column {
            id: col
            anchors {
                left:   parent.left
                right:  parent.right
                top:    parent.top
                margins: 6
            }
            spacing: 0

            Repeater {
                model: opener.children
                delegate: menuRow
            }
        }

        states: [
            State {
                name: "open"; when: root.isOpen
                PropertyChanges { target: panel; opacity: 1.0; y: root.targetY }
            },
            State {
                name: "closed"; when: !root.isOpen
                PropertyChanges { target: panel; opacity: 0.0; y: root.targetY - 10 }
            }
        ]
        transitions: [
            Transition {
                from: "closed"; to: "open"
                SequentialAnimation {
                    ScriptAction { script: root.visible = true }
                    ParallelAnimation {
                        NumberAnimation { target: panel; property: "opacity"; duration: 180; easing.type: Easing.OutQuad }
                        NumberAnimation { target: panel; property: "y";       duration: 180; easing.type: Easing.OutQuad }
                    }
                }
            },
            Transition {
                from: "open"; to: "closed"
                SequentialAnimation {
                    ParallelAnimation {
                        NumberAnimation { target: panel; property: "opacity"; duration: 150; easing.type: Easing.OutQuad }
                        NumberAnimation { target: panel; property: "y";       duration: 150; easing.type: Easing.OutQuad }
                    }
                    ScriptAction { script: root.visible = false }
                }
            }
        ]
    }

    // Recursive menu entry: a row plus its inline-expanded submenu.
    Component {
        id: menuRow

        Column {
            id: r
            required property var modelData
            property bool expanded: false

            width: parent ? parent.width : 0
            spacing: 0

            // Only walks the submenu's DBus entries once expanded.
            QsMenuOpener {
                id: subOpener
                menu: (r.modelData && r.modelData.hasChildren && r.expanded) ? r.modelData : null
            }

            // Separator
            Item {
                width: r.width
                height: 7
                visible: r.modelData.isSeparator
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left:  parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    height: 1
                    color: Theme.surface_container_highest
                    opacity: 0.5
                }
            }

            // Clickable row
            Rectangle {
                id: cell
                width: r.width
                height: 28
                radius: Theme.radius_sm
                visible: !r.modelData.isSeparator
                color: cellHover.hovered ? Theme.surface_container_high : "transparent"

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    // check / radio state
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: r.modelData.buttonType !== 0
                        width: visible ? implicitWidth : 0
                        text: r.modelData.checkState === Qt.Checked ? "" : ""
                        color: Theme.primary
                        font.family: Theme.nerdFont
                        font.pixelSize: 12
                    }

                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: r.modelData.icon !== ""
                        width: visible ? 16 : 0
                        height: 16
                        sourceSize.width: 16
                        sourceSize.height: 16
                        source: r.modelData.icon
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x - chevron.width - 8
                        text: r.modelData.text
                        color: r.modelData.enabled ? Theme.on_surface : Theme.outline
                        font.pixelSize: Theme.fontSize - 3
                        font.family: Theme.font
                        elide: Text.ElideRight
                    }
                }

                Text {
                    id: chevron
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    visible: r.modelData.hasChildren
                    width: visible ? implicitWidth : 0
                    text: r.expanded ? "" : ""
                    color: Theme.outline
                    font.family: Theme.nerdFont
                    font.pixelSize: 11
                }

                HoverHandler { id: cellHover }
                TapHandler {
                    enabled: r.modelData.enabled
                    onTapped: {
                        if (r.modelData.hasChildren) {
                            r.expanded = !r.expanded
                        } else {
                            r.modelData.triggered()
                            root.isOpen = false
                        }
                    }
                }
            }

            // Inline submenu, indented.
            Column {
                x: 12
                width: r.width - 12
                visible: r.expanded
                spacing: 0
                Repeater {
                    model: subOpener.children
                    delegate: menuRow
                }
            }
        }
    }
}
