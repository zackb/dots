import QtQuick
import "../"

Item {
    width:  timeText.width
    height: timeText.height

    property string timeStr: formatTime() // Qt.formatDateTime(new Date(), "ddd dd | h:mm")

    Timer {
        interval:  1000
        running:   true
        repeat:    true
        onTriggered: timeStr = formatTime() // Qt.formatDateTime(new Date(), "ddd dd | h:mm")
    }

    Text {
        id:             timeText
        text:           timeStr
        color:          Theme.textColor
        font.pixelSize: Theme.fontSize
        font.bold:      true
        font.family:    Theme.font
    }

    function formatTime() {
        const now = new Date()
        const days = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
        let h = now.getHours()
        const m = String(now.getMinutes()).padStart(2, "0")
        h = h % 12 || 12
        return `${days[now.getDay()]} ${now.getDate()} | ${h}:${m}`
    }
}
