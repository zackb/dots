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

    property int tempValue: 0
    property string overallTemp: "0°"
    property bool panelHovered: panelHoverHandler.hovered

    readonly property color tempColor: tempValue < 60 ? Theme.battery_high : (tempValue < 80 ? Theme.battery_mid : Theme.battery_low)
    readonly property string tempStatus: tempValue < 60 ? "Normal" : (tempValue < 80 ? "Warm" : "Hot")

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

    Rectangle {
        id: panel
        x: 0; y: 0
        width:  Math.max(contentCol.implicitWidth + 24, 200)
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
                    text: ""
                    color: root.tempColor
                    font.pixelSize: 18
                    font.family: Theme.nerdFont
                }

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "CPU Temperature"
                        color: Theme.textColor
                        font { pixelSize: 13; bold: true; family: Theme.font }
                    }
                    Text {
                        text: root.tempStatus
                        color: root.tempColor
                        font { pixelSize: 11; family: Theme.font }
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: root.overallTemp + "C"
                    color: root.tempColor
                    font { pixelSize: 20; bold: true; family: Theme.font }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.popupBorder
                opacity: 0.5
            }

            // Temperature bar (scale: 0–100°C)
            Rectangle {
                Layout.fillWidth: true
                height: 6
                radius: 3
                color: Theme.surface_container_high

                Rectangle {
                    width: Math.max(Math.min(root.tempValue / 100, 1.0) * parent.width, radius * 2)
                    height: parent.height
                    radius: 3
                    color: root.tempColor
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "0°C";   color: Theme.outline; font { pixelSize: 10; family: Theme.font } }
                Item { Layout.fillWidth: true }
                Text { text: "50°C";  color: Theme.outline; font { pixelSize: 10; family: Theme.font } }
                Item { Layout.fillWidth: true }
                Text { text: "100°C"; color: Theme.outline; font { pixelSize: 10; family: Theme.font } }
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
