// Wayland layer-shell dropdown menu for Bluetooth management,
// positioned directly below the Bar's Bluetooth button.

import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.bluetooth
import qs.theme

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

            if (xCoord < 10) xCoord = 10
            if (xCoord + menuWidth > screenWidth - 10) xCoord = screenWidth - menuWidth - 10

            targetX = xCoord
            targetY = globalY + buttonItem.height + 6

            isOpen = true
        }
    }

    screen: barWindow ? barWindow.screen : null
    visible: false

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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

    color: "transparent"

    MouseArea {
        anchors.fill: parent
        onClicked: root.isOpen = false
        z: -1
    }

    Rectangle {
        id: panel
        x: targetX
        y: targetY
        width: 340
        height: contentCol.implicitHeight + 24
        color: Theme.popupBg
        radius: Theme.radius
        border.color: Theme.popupBorder
        border.width: 1

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.isOpen = false
                event.accepted = true
            }
        }

        Shortcut {
            sequence: "Escape"
            onActivated: root.isOpen = false
        }


        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            color: "transparent"
            border.color: Qt.rgba(0, 0, 0, 0.4)
            border.width: 1
            radius: Theme.radius + 1
            z: -1
        }

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
                    color: Theme.on_surface
                    font { pixelSize: 15; bold: true }
                }

                Item { Layout.fillWidth: true }

                Text {
                    visible: root.adapter && root.adapter.discovering
                    text: "scanning…"
                    color: Theme.warning
                    font.pixelSize: Theme.font_size_sm
                }

                Rectangle {
                    width: 44
                    height: 24
                    radius: 12
                    color: (root.adapter && root.adapter.enabled)
                            ? Theme.primary
                            : Theme.surface_container_high
                    border.color: Theme.surface_container_highest
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: (root.adapter && root.adapter.enabled) ? "ON" : "OFF"
                        color: (root.adapter && root.adapter.enabled)
                               ? Theme.on_primary
                               : Theme.outline
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
                color: Theme.surface_container_highest
                opacity: 0.5
            }

            Text {
                visible: !root.adapter
                text: "No Bluetooth adapter found"
                color: Theme.outline
                font.pixelSize: Theme.fontSize
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                visible: root.adapter && !root.adapter.enabled
                text: "Bluetooth is off"
                color: Theme.outline
                font.pixelSize: Theme.fontSize
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

                    Repeater {
                        model: root.adapter ? root.adapter.devices.values : []
                        delegate: DeviceRow {
                            property var dev: modelData
                            visible: dev && dev.connected
                            device: dev
                            airpodsBattery: root.airpodsBattery
                            onDisconnect: { if(dev) dev.connected = false }
                        }
                    }

                    Text {
                        property var pairedOnly: root.adapter
                             ? root.adapter.devices.values.filter(d => d.paired && !d.connected)
                             : []
                        visible: pairedOnly.length > 0
                        text: "PAIRED"
                        color: Theme.outline
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
                            onConnect: { if(dev) dev.connected = true }
                            onForget: { if(dev) dev.forget() }
                        }
                    }

                    Text {
                        property var discovered: root.adapter
                            ? root.adapter.devices.values.filter(d => !d.paired)
                            : []
                        visible: discovered.length > 0
                        text: "NEARBY"
                        color: Theme.outline
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
                            onPair: { if(dev) dev.pair() }
                        }
                    }

                    Text {
                        visible: root.adapter && root.adapter.enabled
                                 && root.adapter.devices.values.length === 0
                        text: "No devices found — scanning…"
                        color: Theme.outline
                        font.pixelSize: Theme.fontSize
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 8
                    }
                }
            }

            Rectangle {
                visible: root.adapter && root.adapter.enabled
                Layout.fillWidth: true
                height: 36
                radius: Theme.radius_sm
                color: scanHover.containsMouse
                        ? Theme.surface_container_highest
                        : Theme.surface_container_high
                border.color: Theme.surface_container_highest
                border.width: 1
                Layout.topMargin: 4

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: root.adapter && root.adapter.discovering ? "⟳" : "⊕"
                        color: Theme.primary
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
                        text: root.adapter && root.adapter.discovering
                                ? "Stop scanning"
                                : "Scan for devices"
                        color: Theme.on_surface
                        font.pixelSize: Theme.fontSize
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
