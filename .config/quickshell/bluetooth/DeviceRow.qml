// DeviceRow.qml
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: row
    property var device
    property var theme
    property var airpodsBattery: null
    signal connect()
    signal disconnect()
    signal pair()
    signal forget()

    Layout.fillWidth: true
    height: 52
    radius: theme ? theme.radiusSm : 8
    color: mouseArea.containsMouse ? (theme ? theme.bgHover : "#45475a") : (theme ? theme.bgElevated : "#313244")
    border.width: 1
    border.color: theme ? theme.border : "#45475a"

    Text {
        anchors.centerIn: parent
        text: device ? (device.name || device.deviceName || device.address || "?") : "?"
        color: theme ? theme.text : "#cdd6f4"
        font.pixelSize: theme ? theme.fontSz : 13
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