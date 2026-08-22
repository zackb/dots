import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.backend
import qs.theme

// MLB scoreboard for the configured team's game today. Data comes from the fenrizd backend
PanelWindow {

    id: root

    property bool active: true

    // click the score to slide the standings drawer down
    property bool expanded: false

    readonly property var state: Backend.mlbState
    readonly property string gameClass: state.class || "mlb-idle"
    readonly property var standings: state.standings || null

    // the drawer is only worth opening once standings have arrived
    readonly property bool canExpand: standings !== null

    readonly property int rowHeight: 36
    readonly property int drawerPadding: 16

    // standings columns are sized in characters of the monospace face, so they
    // stay aligned if the theme font size changes
    readonly property string tableFont: "monospace"
    function cols(n: int): int {
        return Math.ceil(charWidth.advanceWidth * n)
    }

    TextMetrics {
        id: charWidth
        font.family: root.tableFont
        font.pixelSize: Theme.font_size_sm
        text: "0"
    }

    visible: active && state.active === true

    // never leave a stale expanded surface behind when the game drops off
    onVisibleChanged: if (!visible) expanded = false
    onCanExpandChanged: if (!canExpand) expanded = false

    // pin to top-right corner
    anchors {
        top: true
        right: true
    }

    WlrLayershell.margins.top: 12
    WlrLayershell.margins.right: 12

    // reserve no exclusive zone
    exclusionMode: ExclusionMode.Normal

    // place in the bottom layer
    WlrLayershell.layer: WlrLayer.Bottom

    // anchored top-right, so growth runs down and to the left
    implicitWidth: Math.max(row.implicitWidth, expanded ? table.implicitWidth : 0) + 24
    implicitHeight: rowHeight + (expanded ? table.implicitHeight + drawerPadding : 0)
    color: "transparent"

    Behavior on implicitWidth {
        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
    }
    Behavior on implicitHeight {
        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
    }

    // one club: cap logo (or apprev if unavailable) + score
    component TeamScore: RowLayout {
        required property var team
        readonly property bool hasLogo: team && team.logo ? true : false
        spacing: 4

        Image {
            visible: hasLogo
            source: hasLogo ? "file://" + team.logo : ""
            sourceSize.height: 18
            fillMode: Image.PreserveAspectFit
            Layout.preferredHeight: 18
            Layout.preferredWidth: 18
        }

        // if missing logo
        Text {
            text: team ? (hasLogo ? team.score : team.abbr + " " + team.score) : ""
            color: Theme.textColor
            font.pixelSize: 14
            font.family: "monospace"
        }
    }

    // one standings cell, sized in characters so columns line up across blocks
    component Cell: Text {
        property int chars: 0
        Layout.preferredWidth: root.cols(chars)
        horizontalAlignment: Text.AlignRight
        color: Theme.textColor
        font.pixelSize: Theme.font_size_sm
        font.family: root.tableFont
    }

    component StandHeader: RowLayout {
        spacing: 8

        Cell { text: "#";    chars: 2; color: Theme.outline }
        Cell { text: "TM";   chars: 4; horizontalAlignment: Text.AlignLeft; color: Theme.outline }
        Cell { text: "W-L";  chars: 6; color: Theme.outline }
        Cell { text: "PCT";  chars: 4; color: Theme.outline }
        Cell { text: "GB";   chars: 5; color: Theme.outline }
        Cell { text: "L10";  chars: 5; color: Theme.outline }
        Cell { text: "STRK"; chars: 4; color: Theme.outline }
    }

    component StandRow: RowLayout {
        id: line
        required property var team
        readonly property color fg: line.team.me ? Theme.connected : Theme.textColor
        spacing: 8

        Cell { text: line.team.rank; chars: 2; color: Theme.outline }
        Cell { text: line.team.abbr; chars: 4; horizontalAlignment: Text.AlignLeft; color: line.fg }
        Cell { text: line.team.wins + "-" + line.team.losses; chars: 6; color: line.fg }
        Cell { text: line.team.pct;    chars: 4; color: line.fg }
        Cell { text: line.team.gb;     chars: 5; color: line.fg }
        Cell { text: line.team.l10;    chars: 5; color: line.fg }
        Cell { text: line.team.streak; chars: 4; color: line.fg }
    }

    // block label above a standings table
    component BlockTitle: Text {
        color: Theme.outline
        font.pixelSize: Theme.font_size_sm
        font.family: root.tableFont
        font.bold: true
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius_sm
        // the collapsed pill stays barely-there; the drawer needs to be readable
        // over whatever is behind it
        color: root.expanded ? Theme.popupBg : Qt.rgba(0, 0, 0, 0.4)
        Behavior on color { ColorAnimation { duration: 200 } }
        // dim when showing a stale (last-known) score during a network outage
        opacity: root.state.stale === true ? 0.5 : 1.0
        border.color: root.gameClass === "mlb-live" ? Theme.connected
                    : root.gameClass === "mlb-delay" ? Theme.warning
                    : root.gameClass === "mlb-final" ? Theme.secondary
                    : Theme.outline
        border.width: 1

        Item {
            id: scoreRow
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: root.rowHeight

            RowLayout {
                id: row
                anchors.centerIn: parent
                spacing: 8

                TeamScore { team: root.state.home }
                TeamScore { team: root.state.away }

                Text {
                    visible: text !== ""
                    text: root.state.status || ""
                    color: Theme.textColor
                    font.pixelSize: 14
                    font.family: "monospace"
                }
            }

            TapHandler {
                enabled: root.canExpand
                onTapped: root.expanded = !root.expanded
            }

            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: Qt.openUrlExternally("https://www.mlb.com/scores")
            }
        }

        // standings drawer: masked so the table slides out from under the score
        Item {
            anchors {
                top: scoreRow.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            clip: true

            ColumnLayout {
                id: table
                anchors.top: parent.top
                anchors.topMargin: root.drawerPadding / 2
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 3

                BlockTitle {
                    text: root.standings ? root.standings.division.toUpperCase() : ""
                }

                StandHeader {}

                Repeater {
                    model: root.standings ? root.standings.teams : []
                    delegate: StandRow {
                        required property var modelData
                        team: modelData
                    }
                }

                BlockTitle {
                    visible: repeatWc.count > 0
                    text: "WILD CARD"
                    Layout.topMargin: 6
                }

                StandHeader {
                    visible: repeatWc.count > 0
                }

                Repeater {
                    id: repeatWc
                    model: root.standings ? root.standings.wildCard : []
                    delegate: ColumnLayout {
                        id: wcEntry
                        required property var modelData
                        required property int index
                        spacing: 3
                        Layout.fillWidth: true

                        // the backend appends the team's own line below the playoff spots
                        Rectangle {
                            visible: wcEntry.index >= 3
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Theme.outline
                        }

                        StandRow { team: wcEntry.modelData }
                    }
                }
            }
        }
    }
}
