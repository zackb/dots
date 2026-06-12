import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.backend
import qs.theme

// MLB scoreboard for the configured team's game today. Data comes from the fenrizd backend
PanelWindow {

    id: root

    property bool active: true

    readonly property var state: Backend.mlbState
    readonly property string gameClass: state.class || "mlb-idle"

    visible: active && state.active === true

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

    implicitWidth: row.implicitWidth + 24
    implicitHeight: 36
    color: "transparent"

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

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius_sm
        color: Qt.rgba(0, 0, 0, 0.4)
        border.color: root.gameClass === "mlb-live" ? Theme.connected
                    : root.gameClass === "mlb-final" ? Theme.secondary
                    : Theme.outline
        border.width: 1

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

        ToolTip.visible: hoverHandler.hovered && (root.state.tooltip || "") !== ""
        ToolTip.text: root.state.tooltip || ""
        ToolTip.delay: 400

        HoverHandler {
            id: hoverHandler
        }

        TapHandler {
            onTapped: Qt.openUrlExternally("https://www.mlb.com/scores")
        }
    }
}
