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

    Layout.fillWidth: true
    height: 52
    radius: Theme.radius_sm
    color: mouseArea.containsMouse ? Theme.surface_container_highest : Theme.surface_container_high
    border.width: 1
    border.color: Theme.popupBorder

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
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
