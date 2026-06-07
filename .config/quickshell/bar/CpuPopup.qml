import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../"

PanelWindow {
    id: root

    property var barWindow
    property bool isOpen: false
    property var targetItem
    property int targetX: 0
    property int targetY: 0
    
    // Core data array: { index, pct, freq }
    property var cpuCores: []
    property string cpuModel: "Processor"
    property string overallCpu: "0%"

    screen: barWindow ? barWindow.screen : null
    visible: false

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    onIsOpenChanged: {
        if (isOpen && targetItem && barWindow) {
            var pos = targetItem.mapToItem(null, 0, 0)
            var marginTop = (barWindow && barWindow.margins) ? barWindow.margins.top : 0
            var screenWidth = barWindow ? barWindow.width : 1920
            
            var globalX = pos.x
            var globalY = pos.y + marginTop

            // Width of the popup panel
            var popupWidth = panel.width
            var xCoord = globalX + (targetItem.width / 2) - (popupWidth / 2)
            
            // Clamp to screen boundaries with padding
            if (xCoord < 10) xCoord = 10
            if (xCoord + popupWidth > screenWidth - 10) xCoord = screenWidth - popupWidth - 10

            targetX = xCoord
            targetY = globalY + barWindow.height + 6 // 6px gap below the bar
        }
    }

    // Capture click outside to close if necessary
    MouseArea {
        anchors.fill: parent
        onClicked: root.isOpen = false
        z: -1
    }

    // The actual popup panel
    Rectangle {
        id: panel
        x: targetX
        y: targetY
        width: contentCol.implicitWidth + 24
        height: contentCol.implicitHeight + 24
        color: Theme.popupBg
        radius: Theme.radius
        border.color: Theme.popupBorder
        border.width: 1

        // Drop shadow effect
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            color: "transparent"
            border.color: Qt.rgba(0, 0, 0, 0.4)
            border.width: 1
            radius: Theme.radius + 1
            z: -1
        }

        // Prevent clicks inside panel from closing it
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: contentCol
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 12
                leftMargin: 12
                rightMargin: 12
            }
            spacing: 10

            // Header Section
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // CPU icon
                Text {
                    text: ""
                    color: Theme.primary
                    font.pixelSize: 18
                    font.family: Theme.nerdFont
                }

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: root.cpuModel
                        color: Theme.textColor
                        font { pixelSize: 13; bold: true; family: Theme.font }
                        Layout.maximumWidth: 500
                        elide: Text.ElideRight
                    }
                    Text {
                        text: "Overall Usage: " + root.overallCpu
                        color: Theme.on_surface_variant
                        font { pixelSize: 11; family: Theme.font }
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // Divider line
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.popupBorder
                opacity: 0.5
            }

            // Grid of CPU cores
            Grid {
                id: coresGrid
                columns: 4
                spacing: 10
                Layout.fillWidth: true

                Repeater {
                    model: root.cpuCores

                    delegate: Row {
                        id: coreRow
                        spacing: 8
                        
                        property int pct: modelData.pct
                        property int freq: modelData.freq

                        readonly property color pctColor: {
                            if (pct < 50) return Theme.battery_high
                            if (pct < 80) return Theme.battery_mid
                            return Theme.battery_low
                        }

                        // Core Number
                        Text {
                            text: "C" + (modelData.index < 10 ? "0" + modelData.index : modelData.index)
                            font { family: Theme.nerdFont; pixelSize: 11 }
                            color: Theme.secondary
                            width: 24
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Percentage text
                        Text {
                            text: pct + "%"
                            font { family: Theme.nerdFont; pixelSize: 11; bold: true }
                            color: coreRow.pctColor
                            width: 32
                            horizontalAlignment: Text.AlignRight
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Small usage progress bar
                        Rectangle {
                            width: 50
                            height: 6
                            radius: 3
                            color: Theme.surface_container_high
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                width: (coreRow.pct / 100) * parent.width
                                height: parent.height
                                radius: 3
                                color: coreRow.pctColor
                            }
                        }

                        // Frequency Text
                        Text {
                            text: freq < 1000 ? freq + "M" : (freq / 1000).toFixed(1) + "G"
                            font { family: Theme.nerdFont; pixelSize: 10 }
                            color: Theme.outline
                            width: 36
                            horizontalAlignment: Text.AlignRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }

        states: [
            State {
                name: "open"
                when: root.isOpen
                PropertyChanges { target: panel; opacity: 1.0; y: root.targetY }
            },
            State {
                name: "closed"
                when: !root.isOpen
                PropertyChanges { target: panel; opacity: 0.0; y: root.targetY - 10 }
            }
        ]

        transitions: [
            Transition {
                from: "closed"
                to: "open"
                SequentialAnimation {
                    ScriptAction { script: root.visible = true }
                    ParallelAnimation {
                        NumberAnimation { target: panel; property: "opacity"; duration: 180; easing.type: Easing.OutQuad }
                        NumberAnimation { target: panel; property: "y"; duration: 180; easing.type: Easing.OutQuad }
                    }
                }
            },
            Transition {
                from: "open"
                to: "closed"
                SequentialAnimation {
                    ParallelAnimation {
                        NumberAnimation { target: panel; property: "opacity"; duration: 150; easing.type: Easing.OutQuad }
                        NumberAnimation { target: panel; property: "y"; duration: 150; easing.type: Easing.OutQuad }
                    }
                    ScriptAction { script: root.visible = false }
                }
            }
        ]
    }
}
