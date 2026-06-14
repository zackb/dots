import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import qs.backend
import qs.theme

// Upcoming calendar events, pinned top-right on the desktop.
// Data is the next few events from the fenrizd calendar service.
PanelWindow {
    id: root

    property bool active: true

    readonly property var upcoming: Backend.calendarState.upcoming || []

    visible: active && upcoming.length > 0

    anchors {
        top: true
        right: true
    }
    // Stack under the score capsule (top-right, 36px tall) when a game is live;
    // otherwise sit at the top. Keeps the two desktop widgets from overlapping.
    readonly property bool scoreShowing: active && (Backend.mlbState.active === true)
    WlrLayershell.margins.top: 12 + (scoreShowing ? 46 : 0)
    WlrLayershell.margins.right: 12

    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Bottom

    implicitWidth: 340
    // Fit content, but cap so a busy calendar scrolls instead of filling the screen.
    readonly property int maxListHeight: 320
    implicitHeight: header.height + Math.min(list.contentHeight, maxListHeight) + 20
    color: "transparent"

    // Human "when" label: Today/Tomorrow/weekday/date + time (or All day).
    function whenLabel(ev) {
        const d = new Date(ev.start);
        const now = new Date();
        const midnight = x => new Date(x.getFullYear(), x.getMonth(), x.getDate());
        const days = Math.round((midnight(d) - midnight(now)) / 86400000);
        let day;
        if (days === 0)
            day = "Today";
        else if (days === 1)
            day = "Tomorrow";
        else if (days > 1 && days < 7)
            day = Qt.formatDate(d, "dddd");
        else
            day = Qt.formatDate(d, "ddd MMM d");
        return ev.allDay ? day + " · All day" : day + " · " + Qt.formatTime(d, "h:mm AP");
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius_sm
        color: Qt.rgba(0, 0, 0, 0.4)
        border.color: Theme.outline
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            Row {
                id: header
                width: parent.width
                spacing: 6

                Text {
                    text: "calendar_month"
                    color: Theme.primary
                    font.family: Theme.ligatureFont
                    font.pixelSize: 16
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "Upcoming"
                    color: Theme.on_surface_variant
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            ListView {
                id: list
                width: parent.width
                height: Math.min(contentHeight, root.maxListHeight)
                clip: true
                model: root.upcoming
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: list.contentHeight > list.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                }

                delegate: Item {
                    required property var modelData
                    width: ListView.view.width
                    height: rowCol.implicitHeight + 8

                    // left accent strip
                    Rectangle {
                        id: accent
                        width: 3
                        height: rowCol.implicitHeight
                        radius: 2
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                    }

                    Column {
                        id: rowCol
                        anchors.left: accent.right
                        anchors.right: parent.right
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: root.whenLabel(modelData)
                            color: Theme.secondary
                            font.family: Theme.font
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: modelData.summary || "(no title)"
                            color: Theme.textColor
                            font.family: Theme.font
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            visible: (modelData.location || "") !== ""
                            text: (modelData.location || "").split("\n")[0]
                            color: Theme.on_surface_variant
                            font.family: Theme.font
                            font.pixelSize: Theme.font_size_sm
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // Click anywhere opens the full calendar app
        TapHandler {
            onTapped: Quickshell.execDetached(["betterbird", "-calendar"])
        }
    }
}
