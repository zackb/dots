import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs

PanelWindow {
    id: root

    property var barWindow
    property bool isOpen: false
    property var targetItem
    property int targetX: 0
    property int targetY: 0

    property int diskUsed:  0
    property int diskTotal: 1
    property int diskAvail: 0
    property string overallDisk: "0%"
    property bool panelHovered: panelHoverHandler.hovered

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
        panel.y = -10
    }

    onIsOpenChanged: {
        if (isOpen && targetItem && barWindow) {
            var pos = targetItem.mapToItem(null, 0, 0)
            var marginTop = (barWindow && barWindow.margins) ? barWindow.margins.top : 0
            var screenWidth = barWindow ? barWindow.width : 1920
            var globalX = pos.x
            var globalY = pos.y + marginTop
            var popupWidth = panel.width
            var xCoord = globalX + (targetItem.width / 2) - (popupWidth / 2)
            if (xCoord < 10) xCoord = 10
            if (xCoord + popupWidth > screenWidth - 10) xCoord = screenWidth - popupWidth - 10
            targetX = xCoord
            targetY = globalY + barWindow.height + 6
        }
    }

    function toGB(mb) { return (mb / 1024).toFixed(1) }

    Rectangle {
        id: panel
        x: 0; y: 0
        width:  Math.max(contentCol.implicitWidth + 24, 230)
        height: contentCol.implicitHeight + 24
        color: Theme.popupBg
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

        HoverHandler { id: panelHoverHandler }

        ColumnLayout {
            id: contentCol
            anchors {
                top: parent.top; left: parent.left; right: parent.right
                topMargin: 12; leftMargin: 12; rightMargin: 12
            }
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "󰋊"
                    color: Theme.tertiary
                    font.pixelSize: 18
                    font.family: Theme.nerdFont
                }

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "Storage"
                        color: Theme.textColor
                        font { pixelSize: 13; bold: true; family: Theme.font }
                    }
                    Text {
                        text: "Usage: " + root.overallDisk
                        color: Theme.on_surface_variant
                        font { pixelSize: 11; family: Theme.font }
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: root.toGB(root.diskUsed) + " / " + root.toGB(root.diskTotal) + " GB"
                    color: Theme.textColor
                    font { pixelSize: 12; family: Theme.font }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.popupBorder
                opacity: 0.5
            }

            Rectangle {
                Layout.fillWidth: true
                height: 6
                radius: 3
                color: Theme.surface_container_high

                readonly property real pct: root.diskTotal > 0 ? root.diskUsed / root.diskTotal : 0
                readonly property color fillColor: pct < 0.5 ? Theme.battery_high : (pct < 0.8 ? Theme.battery_mid : Theme.battery_low)

                Rectangle {
                    width: parent.pct * parent.width
                    height: parent.height
                    radius: 3
                    color: parent.fillColor
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Used";      color: Theme.on_surface_variant; font { pixelSize: 11; family: Theme.font } }
                    Item { Layout.fillWidth: true }
                    Text { text: root.toGB(root.diskUsed)  + " GB"; color: Theme.textColor; font { pixelSize: 11; family: Theme.font } }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Available"; color: Theme.on_surface_variant; font { pixelSize: 11; family: Theme.font } }
                    Item { Layout.fillWidth: true }
                    Text { text: root.toGB(root.diskAvail) + " GB"; color: Theme.textColor; font { pixelSize: 11; family: Theme.font } }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Total";     color: Theme.on_surface_variant; font { pixelSize: 11; family: Theme.font } }
                    Item { Layout.fillWidth: true }
                    Text { text: root.toGB(root.diskTotal) + " GB"; color: Theme.textColor; font { pixelSize: 11; family: Theme.font } }
                }
            }
        }

        states: [
            State { name: "open";   when: root.isOpen;  PropertyChanges { target: panel; opacity: 1.0; y: 0   } },
            State { name: "closed"; when: !root.isOpen; PropertyChanges { target: panel; opacity: 0.0; y: -10 } }
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
}
