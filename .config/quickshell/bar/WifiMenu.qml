// Click-dismissed popup for Wi-Fi: scan, connect (with password), forget, and
// toggle the radio. Replaces `hyprwat --wifi`; actions go to the fenrizd `wifi`
// service via Backend.command, results stream back on Backend.wifiState.

import QtQuick
import QtQuick.Layouts
import qs.backend
import qs.components
import qs.theme

OverlayPopup {
    id: root

    panelWidth: 340
    contentSpacing: 4

    readonly property var wifi: Backend.wifiState

    // SSID whose inline password field is currently expanded ("" = none).
    property string passwordFor: ""

    function signalIcon(strength) {
        if (strength < 25) return "󰤟"
        if (strength < 50) return "󰤢"
        if (strength < 75) return "󰤥"
        return                    "󰤨"
    }

    // Saved or open networks join immediately; a new secured one reveals a field.
    function activate(n) {
        if (n.active) return
        if (n.secured && !n.saved) {
            root.passwordFor = (root.passwordFor === n.ssid) ? "" : n.ssid
            return
        }
        Backend.command("wifi", "connect", { ssid: n.ssid })
    }

    onIsOpenChanged: {
        if (!isOpen) {
            root.passwordFor = ""
            return
        }
        Backend.command("wifi", "scan", {})
    }

    // Keep signal / active state fresh while the popup is open.
    Timer {
        interval: 5000
        repeat: true
        running: root.isOpen
        onTriggered: Backend.command("wifi", "list", {})
    }

    // One access point: header row + (optionally) an inline password field.
    component NetworkRow: ColumnLayout {
        id: rowItem
        required property var modelData
        Layout.fillWidth: true
        spacing: 4

        readonly property bool expanded: root.passwordFor === modelData.ssid

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 32
            radius: Theme.radius_sm
            color: rowMA.containsMouse ? Theme.surface_container_high : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }

            // Row click = connect/activate. Declared first so it sits beneath
            // the forget button, whose own MouseArea consumes its clicks.
            MouseArea {
                id: rowMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activate(rowItem.modelData)
            }

            RowLayout {
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                spacing: 8

                Text {
                    text: root.signalIcon(rowItem.modelData.signal)
                    color: rowItem.modelData.active ? Theme.primary : Theme.on_surface_variant
                    font { family: Theme.nerdFont; pixelSize: 14 }
                }
                Text {
                    Layout.fillWidth: true
                    text: rowItem.modelData.ssid
                    color: rowItem.modelData.active ? Theme.textColor : Theme.on_surface_variant
                    elide: Text.ElideRight
                    font { family: Theme.font; pixelSize: Theme.fontSize; bold: rowItem.modelData.active }
                }
                Text {
                    visible: rowItem.modelData.secured
                    text: "󰌾"
                    color: Theme.outline
                    font { family: Theme.nerdFont; pixelSize: 12 }
                }
                // Forget a saved network. Nested MouseArea consumes the click
                // so the row's connect handler doesn't also fire.
                Text {
                    visible: rowItem.modelData.saved
                    text: "󰩹"
                    color: forgetMA.containsMouse ? Theme.critical : Theme.outline
                    font { family: Theme.nerdFont; pixelSize: 13 }
                    MouseArea {
                        id: forgetMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Backend.command("wifi", "forget", { ssid: rowItem.modelData.ssid })
                    }
                }
                Text {
                    visible: rowItem.modelData.active
                    text: "󰄬"
                    color: Theme.primary
                    font { family: Theme.nerdFont; pixelSize: 13 }
                }
            }
        }

        // Inline password entry for a new secured network.
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            visible: rowItem.expanded
            implicitHeight: 30
            radius: Theme.radius_sm
            color: Theme.surface_container_high
            border.color: pwInput.activeFocus ? Theme.primary : Theme.popupBorder
            border.width: 1

            RowLayout {
                anchors { fill: parent; leftMargin: 8; rightMargin: 4 }
                spacing: 6

                TextInput {
                    id: pwInput
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    color: Theme.textColor
                    font { family: Theme.font; pixelSize: Theme.fontSize }
                    clip: true
                    verticalAlignment: TextInput.AlignVCenter
                    focus: rowItem.expanded
                    onAccepted: {
                        Backend.command("wifi", "connect", { ssid: rowItem.modelData.ssid, password: text })
                        root.passwordFor = ""
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pwInput.text === ""
                        text: "Password"
                        color: Theme.outline
                        font: pwInput.font
                    }
                }
                Text {
                    text: "󰌑"
                    color: Theme.primary
                    font { family: Theme.nerdFont; pixelSize: 14 }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: pwInput.accepted() }
                }
            }
        }
    }

    // Header: title + rescan + radio toggle.
    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: "Wi-Fi"
            color: Theme.outline
            font { pixelSize: 10; letterSpacing: 1.5; bold: true; family: Theme.font }
        }
        Text {
            text: "󰑐"
            color: rescanHover.hovered ? Theme.primary : Theme.outline
            font { family: Theme.nerdFont; pixelSize: 14 }
            visible: root.wifi.enabled
            HoverHandler { id: rescanHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: Backend.command("wifi", "scan", {}) }
        }
        // Radio toggle pill.
        Rectangle {
            implicitWidth: 36
            implicitHeight: 18
            radius: height / 2
            color: root.wifi.enabled ? Theme.primary : Theme.surface_container_highest
            Behavior on color { ColorAnimation { duration: 120 } }

            Rectangle {
                width: 14; height: 14; radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: root.wifi.enabled ? parent.width - width - 2 : 2
                color: root.wifi.enabled ? Theme.on_primary : Theme.outline
                Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
            }

            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: Backend.command("wifi", "radio", { on: !root.wifi.enabled }) }
        }
    }

    Repeater {
        model: root.wifi.enabled ? root.wifi.networks : []
        delegate: NetworkRow {}
    }

    Text {
        visible: root.wifi.enabled && root.wifi.networks.length === 0
        text: "No networks found"
        color: Theme.outline
        font { family: Theme.font; pixelSize: Theme.fontSize }
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 6
        Layout.bottomMargin: 6
    }

    Text {
        visible: !root.wifi.enabled
        text: "Wi-Fi is off"
        color: Theme.outline
        font { family: Theme.font; pixelSize: Theme.fontSize }
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 6
        Layout.bottomMargin: 6
    }

    // Footer status: connecting / last error.
    Text {
        visible: root.wifi.connecting || root.wifi.error !== ""
        Layout.fillWidth: true
        Layout.topMargin: 4
        text: root.wifi.connecting ? "Connecting…" : root.wifi.error
        color: root.wifi.connecting ? Theme.outline : Theme.critical
        wrapMode: Text.WordWrap
        font { family: Theme.font; pixelSize: Theme.font_size_sm }
    }
}
