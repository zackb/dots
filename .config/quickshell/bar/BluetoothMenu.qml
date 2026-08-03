// Wayland layer-shell dropdown menu for Bluetooth management,
// positioned directly below the Bar's Bluetooth button.

import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.backend
import qs.bluetooth
import qs.components
import qs.theme

OverlayPopup {
    id: root

    panelWidth: 340
    centerOnAnchor: true

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property var airpodsBattery: Backend.airpods

    Timer {
        id: scanTimer
        interval: 15000
        onTriggered: {
            if (root.adapter) root.adapter.discovering = false
        }
    }

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
