import QtQuick

Item {
    width:  timeText.width
    height: timeText.height

    property string timeStr: Qt.formatDateTime(new Date(), "ddd dd | HH:mm")

    Timer {
        interval:  1000
        running:   true
        repeat:    true
        onTriggered: timeStr = Qt.formatDateTime(new Date(), "ddd dd | hh:mm")
    }

    Text {
        id:             timeText
        text:           timeStr
        color:          "#ddd"
        font.pixelSize: 16
        font.bold:      true
        font.family:      "Cantarell"
    }
}
