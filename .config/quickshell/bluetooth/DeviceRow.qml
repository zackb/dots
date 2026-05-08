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
    color: theme ? theme.bgElevated : "#24253a"
    border.width: 1
    border.color: theme ? theme.border : "#414868"

    Text {
        anchors.centerIn: parent
        text: device ? (device.name || device.deviceName || device.address || "?") : "?"
        color: theme ? theme.text : "#c0caf5"
        font.pixelSize: theme ? theme.fontSz : 13
    }
}