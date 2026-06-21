// DeviceRow.qml
import QtQuick
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: row
    property var device
    property var airpodsBattery: null
    signal connect()
    signal disconnect()
    signal pair()
    signal forget()

    // Only the connected AirPods row shows battery bars, matched by the
    // connection MAC the backend reports (the device's name may be customised).
    readonly property bool showBattery: device && device.connected
        && airpodsBattery && airpodsBattery.connected && airpodsBattery.address
        && (device.address || "").toUpperCase() === airpodsBattery.address.toUpperCase()

    Layout.fillWidth: true
    implicitHeight: Math.max(52, content.implicitHeight + 16)
    Layout.preferredHeight: implicitHeight
    radius: Theme.radius_sm
    color: mouseArea.containsMouse ? Theme.surface_container_highest : Theme.surface_container_high
    border.width: 1
    border.color: Theme.popupBorder

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Pulsing indicator for connected devices
            Item {
                width: 12
                height: 12
                visible: device && device.connected

                Rectangle {
                    anchors.centerIn: parent
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.connected

                    Rectangle {
                        anchors.centerIn: parent
                        width: 8
                        height: 8
                        radius: 4
                        color: parent.color
                        opacity: 0.6

                        SequentialAnimation on scale {
                            running: device && device.connected
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 2.5; duration: 1200; easing.type: Easing.OutQuad }
                        }
                        SequentialAnimation on opacity {
                            running: device && device.connected
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.6; to: 0.0; duration: 1200; easing.type: Easing.OutQuad }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: device ? (device.name || device.deviceName || device.address || "?") : "?"
                color: Theme.on_surface
                font.pixelSize: 13
                font.bold: device && device.connected
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignLeft
            }

            Text {
                visible: device && device.connected
                text: "Connected"
                color: Theme.connected
                font.pixelSize: Theme.font_size_sm
            }
        }

        ColumnLayout {
            visible: row.showBattery
            Layout.leftMargin: 24
            spacing: 2

            AirpodBudBar { label: "L";    pct: row.airpodsBattery ? row.airpodsBattery.left  : -1 }
            AirpodBudBar { label: "R";    pct: row.airpodsBattery ? row.airpodsBattery.right : -1 }
            AirpodBudBar { label: "Case"; pct: row.airpodsBattery ? row.airpodsBattery.case  : -1 }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (!device) return;
            if (mouse.button === Qt.RightButton) {
                if (device.paired) {
                    row.forget()
                }
            } else {
                if (device.connected) {
                    row.disconnect()
                } else if (device.paired) {
                    row.connect()
                } else {
                    row.pair()
                }
            }
        }
    }
}
