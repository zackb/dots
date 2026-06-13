import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

AnchoredPopup {
    id: root
    contentSpacing: 6

    readonly property int cellSize: 28
    readonly property int cellGap:  4
    readonly property int gridW:    7 * cellSize + 6 * cellGap
    minWidth: gridW

    property int displayMonth: new Date().getMonth()
    property int displayYear:  new Date().getFullYear()

    property var calendarDays: _buildDays(displayMonth, displayYear)

    function prevMonth() {
        if (displayMonth === 0) { displayMonth = 11; displayYear-- }
        else displayMonth--
    }

    function nextMonth() {
        if (displayMonth === 11) { displayMonth = 0; displayYear++ }
        else displayMonth++
    }

    function _buildDays(month, year) {
        var firstDay = new Date(year, month, 1).getDay()
        var daysInMonth = new Date(year, month + 1, 0).getDate()
        var daysInPrev  = new Date(year, month, 0).getDate()
        var now = new Date()
        var days = []
        for (var i = firstDay - 1; i >= 0; i--)
            days.push({ day: daysInPrev - i, current: false, today: false })
        for (var d = 1; d <= daysInMonth; d++)
            days.push({
                day: d,
                current: true,
                today: d === now.getDate() && month === now.getMonth() && year === now.getFullYear()
            })
        var total = days.length <= 35 ? 35 : 42
        for (var n = 1; days.length < total; n++)
            days.push({ day: n, current: false, today: false })
        return days
    }

    // Reset to the current month and center on screen each time it opens.
    onIsOpenChanged: {
        if (!isOpen) return
        var now = new Date()
        displayMonth = now.getMonth()
        displayYear  = now.getFullYear()
        if (barWindow) {
            var marginTop  = barWindow.margins ? barWindow.margins.top : 0
            var screenW    = barWindow.width > 0 ? barWindow.width : 1920
            targetX = Math.round((screenW - root.panelWidth) / 2)
            targetY = marginTop + barWindow.height + 6
        }
    }

    // Header
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Text {
            text: Qt.formatDate(new Date(root.displayYear, root.displayMonth, 1), "MMMM yyyy")
            color: Theme.textColor
            font { pixelSize: 13; bold: true; family: Theme.font }
            Layout.fillWidth: true
        }

        Rectangle {
            width: 22; height: 22; radius: 11
            color: prevHover.hovered ? Theme.surface_container_high : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
            Text {
                anchors.centerIn: parent
                text: "‹"
                color: Theme.textColor
                font { pixelSize: 15; family: Theme.font }
            }
            HoverHandler { id: prevHover }
            TapHandler { onTapped: root.prevMonth() }
        }

        Rectangle {
            width: 22; height: 22; radius: 11
            color: nextHover.hovered ? Theme.surface_container_high : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
            Text {
                anchors.centerIn: parent
                text: "›"
                color: Theme.textColor
                font { pixelSize: 15; family: Theme.font }
            }
            HoverHandler { id: nextHover }
            TapHandler { onTapped: root.nextMonth() }
        }
    }

    // Divider
    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Theme.popupBorder
        opacity: 0.5
    }

    // Day-of-week header
    Row {
        spacing: root.cellGap
        Repeater {
            model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
            Text {
                width: root.cellSize
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: Theme.on_surface_variant
                font { pixelSize: 10; family: Theme.font }
            }
        }
    }

    // Day grid
    Grid {
        columns: 7
        spacing: root.cellGap

        Repeater {
            model: root.calendarDays
            delegate: Rectangle {
                width: root.cellSize
                height: root.cellSize
                radius: root.cellSize / 2

                color: modelData.today ? Theme.primary :
                       (cellHover.hovered ? Theme.surface_container_high : "transparent")
                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: modelData.day
                    color: modelData.today   ? Theme.on_primary :
                           modelData.current ? Theme.textColor   : Theme.on_surface_variant
                    font { pixelSize: 11; family: Theme.font; bold: modelData.today }
                }

                HoverHandler { id: cellHover; enabled: modelData.current }
            }
        }
    }
}
