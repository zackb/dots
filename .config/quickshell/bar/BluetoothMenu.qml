// Wayland layer-shell dropdown menu for Bluetooth management,
// positioned directly below the Bar's Bluetooth button.

import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../bluetooth"
import "../"

PanelWindow {
    id: root

    property var barWindow
    property bool isOpen: false
    property int targetX: 0
    property int targetY: 0

    function toggleMenu(buttonItem) {
        if (isOpen) {
            isOpen = false
        } else {
            var pos = buttonItem.mapToItem(null, 0, 0)
            var marginTop = (barWindow && barWindow.margins) ? barWindow.margins.top : 0
            var screenWidth = barWindow ? barWindow.width : 1920
            
            var globalX = pos.x
            var globalY = pos.y + marginTop

            var menuWidth = 340
            var xCoord = globalX + (buttonItem.width / 2) - (menuWidth / 2)
            
            // clamp to screen boundaries with padding
            if (xCoord < 10) xCoord = 10
            if (xCoord + menuWidth > screenWidth - 10) xCoord = screenWidth - menuWidth - 10

            targetX = xCoord
            targetY = globalY + buttonItem.height + 6 // 6px gap below the button

            isOpen = true
        }
    }

    // associate window with the correct screen
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

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter

    Timer {
        id: scanTimer
        interval: 15000
        onTriggered: {
            if (root.adapter) root.adapter.discovering = false
        }
    }

    property var airpodsBattery: null

    QtObject {
        id: theme
        property color bg:           Qt.alpha("#1e1e2e", 0.95)
        property color bgElevated:   "#313244"
        property color bgHover:      "#45475a"
        property color border:       "#45475a"
        property color text:         "#cdd6f4"
        property color textDim:      "#6c7086"
        property color textBright:   "#cdd6f4"
        property color accent:       "#cba6f7"
        property color accentDim:    "#45475a"
        property color connected:    "#a6e3a1"
        property color disconnected: "#6c7086"
        property color scanning:     "#f9e2af"
        property color batteryHigh:  "#a6e3a1"
        property color batteryMid:   "#f9e2af"
        property color batteryLow:   "#f38ba8"
        property color danger:       "#f38ba8"
        property int   radius:       12
        property int   radiusSm:     8
        property int   fontSz:       13
        property int   fontSzSm:     11
    }

    color: "transparent"

    MouseArea {
        anchors.fill: parent
        onClicked: root.isOpen = false
        z: -1
    }

    // Dropdown Panel 
    Rectangle {
        id: panel
        x: targetX
        y: targetY
        width: 340
        height: contentCol.implicitHeight + 24
        color: theme.bg
        radius: theme.radius
        border.color: theme.border
        border.width: 1

        // Drop shadow effect
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            color: "transparent"
            border.color: Qt.rgba(0, 0, 0, 0.4)
            border.width: 1
            radius: theme.radius + 1
            z: -1
        }

        // Catch clicks inside the panel so they don't fall through
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
                bottomMargin: 12
            }
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Bluetooth"
                    color: theme.textBright
                    font { pixelSize: 15; bold: true }
                }

                Item { Layout.fillWidth: true }

                // Scanning indicator
                Text {
                    visible: root.adapter && root.adapter.discovering
                    text: "scanning…"
                    color: theme.scanning
                    font.pixelSize: theme.fontSzSm
                }

                // Adapter power toggle
                Rectangle {
                    width: 44
                    height: 24
                    radius: 12
                    color: (root.adapter && root.adapter.enabled)
                            ? theme.accent
                            : theme.bgElevated
                    border.color: theme.border
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: (root.adapter && root.adapter.enabled) ? "ON" : "OFF"
                        color: (root.adapter && root.adapter.enabled)
                               ? "#11111b"
                               : theme.textDim
                        font { pixelSize: 10; bold: true }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.adapter)
                                root.adapter.enabled = !root.adapter.enabled
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: theme.border
                opacity: 0.5
            }

            Text {
                visible: !root.adapter
                text: "No Bluetooth adapter found"
                color: theme.textDim
                font.pixelSize: theme.fontSz
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                visible: root.adapter && !root.adapter.enabled
                text: "Bluetooth is off"
                color: theme.textDim
                font.pixelSize: theme.fontSz
                Layout.alignment: Qt.AlignHCenter
            }

            ScrollView {
                id: deviceScroll
                visible: root.adapter && root.adapter.enabled
                Layout.fillWidth: true
                Layout.maximumHeight: 320
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ColumnLayout {
                    width: deviceScroll.availableWidth
                    spacing: 4

                    // Section: Connected
                    Repeater {
                        model: root.adapter ? root.adapter.devices.values : []
                        delegate: DeviceRow {
                            property var dev: modelData
                            visible: dev && dev.connected
                            device: dev
                            airpodsBattery: root.airpodsBattery
                            theme: theme
                            onDisconnect: { if(dev) dev.connected = false }
                        }
                    }

                    // Section header: Paired (not connected)
                    Text {
                        property var pairedOnly: root.adapter
                             ? root.adapter.devices.values.filter(d => d.paired && !d.connected)
                             : []
                        visible: pairedOnly.length > 0
                        text: "PAIRED"
                        color: theme.textDim
                        font { pixelSize: 10; letterSpacing: 1.5; bold: true }
                        Layout.topMargin: 4
                    }

                    Repeater {
                        model: root.adapter ? root.adapter.devices.values : []
                        delegate: DeviceRow {
                            property var dev: modelData
                            visible: dev && dev.paired && !dev.connected
                            device: dev
                            airpodsBattery: null
                            theme: theme
                            onConnect: { if(dev) dev.connected = true }
                            onForget: { if(dev) dev.forget() }
                        }
                    }

                    // Section header: Discovered (not paired)
                    Text {
                        property var discovered: root.adapter
                            ? root.adapter.devices.values.filter(d => !d.paired)
                            : []
                        visible: discovered.length > 0
                        text: "NEARBY"
                        color: theme.textDim
                        font { pixelSize: 10; letterSpacing: 1.5; bold: true }
                        Layout.topMargin: 4
                    }

                    Repeater {
                        model: root.adapter ? root.adapter.devices.values : []
                        delegate: DeviceRow {
                            property var dev: modelData
                            visible: dev && !dev.paired
                            device: dev
                            airpodsBattery: null
                            theme: theme
                            onPair: { if(dev) dev.pair() }
                        }
                    }

                    // Empty state when enabled but nothing found yet
                    Text {
                        visible: root.adapter && root.adapter.enabled
                                 && root.adapter.devices.values.length === 0
                        text: "No devices found — scanning…"
                        color: theme.textDim
                        font.pixelSize: theme.fontSz
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 8
                    }
                }
            }

            Rectangle {
                visible: root.adapter && root.adapter.enabled
                Layout.fillWidth: true
                height: 36
                radius: theme.radiusSm
                color: scanHover.containsMouse ? theme.bgHover : theme.bgElevated
                border.color: theme.border
                border.width: 1
                Layout.topMargin: 4

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: root.adapter && root.adapter.discovering ? "⟳" : "⊕"
                        color: theme.accent
                        font.pixelSize: 16

                        RotationAnimation on rotation {
                            running: root.adapter && root.adapter.discovering
                            from: 0
                            to: 360
                            duration: 1500
                            loops: Animation.Infinite
                        }
                    }

                    Text {
                        text: root.adapter && root.adapter.discovering ? "Stop scanning" : "Scan for devices"
                        color: theme.text
                        font.pixelSize: theme.fontSz
                    }
                }

                MouseArea {
                    id: scanHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.adapter) return
                        if (root.adapter.discovering) {
                            root.adapter.discovering = false
                            scanTimer.stop()
                        } else {
                            root.adapter.discovering = true
                            scanTimer.restart()
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
