import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.theme

PanelWindow {
    id: root

    property var barWindow
    property bool isOpen: false
    property int targetX: 0
    property int targetY: 0
    property bool panelHovered: panelHoverHandler.hovered

    property int displayMonth: new Date().getMonth()
    property int displayYear:  new Date().getFullYear()

    property var calendarDays: _buildDays(displayMonth, displayYear)

    screen: barWindow ? barWindow.screen : null
    visible: false

    anchors { top: true; left: true }
    margins { top: root.targetY; left: root.targetX }

    implicitWidth:  panel.width
    implicitHeight: panel.height

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    function closeNow() {
        root.visible = false
        panel.opacity = 0
        panel.y = -10
    }

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

    onIsOpenChanged: {
        if (!isOpen) return
        var now = new Date()
        displayMonth = now.getMonth()
        displayYear  = now.getFullYear()
        if (barWindow) {
            var marginTop  = barWindow.margins ? barWindow.margins.top : 0
            var screenW    = barWindow.width > 0 ? barWindow.width : 1920
            targetX = Math.round((screenW - panel.width) / 2)
            targetY = marginTop + barWindow.height + 6
        }
    }

    Rectangle {
        id: panel
        x: 0; y: 0

        readonly property int cellSize: 28
        readonly property int cellGap:  4
        readonly property int gridW:    7 * cellSize + 6 * cellGap

        width:  gridW + 24
        height: calContent.implicitHeight + 24
        color:  Theme.popupBg
        radius: Theme.radius
        border.color: Theme.popupBorder
        border.width: 1

        Rectangle {
            anchors { fill: parent; margins: -1 }
            color: "transparent"
            border.color: Qt.rgba(0, 0, 0, 0.4)
            border.width: 1
            radius: Theme.radius + 1
            z: -1
        }

        HoverHandler { id: panelHoverHandler }

        ColumnLayout {
            id: calContent
            anchors {
                top: parent.top; left: parent.left; right: parent.right
                topMargin: 12; leftMargin: 12; rightMargin: 12
            }
            spacing: 6

            // ── Header ───────────────────────────────────────────
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

            // ── Divider ──────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.popupBorder
                opacity: 0.5
            }

            // ── Day-of-week header ────────────────────────────────
            Row {
                spacing: panel.cellGap
                Repeater {
                    model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                    Text {
                        width: panel.cellSize
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Theme.on_surface_variant
                        font { pixelSize: 10; family: Theme.font }
                    }
                }
            }

            // ── Day grid ─────────────────────────────────────────
            Grid {
                columns: 7
                spacing: panel.cellGap

                Repeater {
                    model: root.calendarDays
                    delegate: Rectangle {
                        width: panel.cellSize
                        height: panel.cellSize
                        radius: panel.cellSize / 2

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

        states: [
            State { name: "open";   when: root.isOpen;  PropertyChanges { target: panel; opacity: 1.0; y: 0   } },
            State { name: "closed"; when: !root.isOpen; PropertyChanges { target: panel; opacity: 0.0; y: -10 } }
        ]
        transitions: [
            Transition {
                from: "closed"; to: "open"
                SequentialAnimation {
                    ScriptAction { script: root.visible = true }
                    ParallelAnimation {
                        NumberAnimation { target: panel; property: "opacity"; duration: 180; easing.type: Easing.OutQuad }
                        NumberAnimation { target: panel; property: "y";       duration: 180; easing.type: Easing.OutQuad }
                    }
                }
            },
            Transition {
                from: "open"; to: "closed"
                SequentialAnimation {
                    ParallelAnimation {
                        NumberAnimation { target: panel; property: "opacity"; duration: 150; easing.type: Easing.OutQuad }
                        NumberAnimation { target: panel; property: "y";       duration: 150; easing.type: Easing.OutQuad }
                    }
                    ScriptAction { script: root.visible = false }
                }
            }
        ]
    }
}
