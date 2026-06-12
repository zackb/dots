import QtQuick
import qs.theme

Item {
    id: root
    width:  timeText.width
    height: timeText.height

    property var barWindow
    property bool calIsOpen: false

    property string timeStr: formatTime()

    Timer {
        interval:  1000
        running:   true
        repeat:    true
        onTriggered: timeStr = formatTime()
    }

    Text {
        id:             timeText
        text:           timeStr
        color:          Theme.textColor
        font.pixelSize: Theme.fontSize
        font.bold:      true
        font.family:    Theme.font
    }

    TapHandler {
        onTapped: root.calIsOpen = !root.calIsOpen
    }

    CalendarPopup {
        id: calPopup
        barWindow: root.barWindow
        isOpen:    root.calIsOpen
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
