import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import Quickshell.Wayland
import "../"

PanelWindow {

    id: root

    property bool active: true
    property bool hasData: false

    visible: active && hasData

    // pin to bottom-right corner
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

    implicitWidth: scoreText.implicitWidth + 24
    implicitHeight: 36
    color: "transparent"

    property string scoreText: ""
    property string tooltipText: ""
    property string gameClass: "mlb-idle"

    // re-fetch every 2 minutes
    Timer {
        interval: 120000
        running: active
        repeat: true
        triggeredOnStart: true
        onTriggered: mlbProcess.running = true
    }

    Process {
        id: mlbProcess
        running: active
        command: ["python3", Qt.resolvedUrl("mlb.py").toString().replace("file://", "")]
        stderr: SplitParser {
            onRead: data => console.log("mlb stderr:", data)
        }

        stdout: SplitParser {
            onRead: data => {
                try {
                    const j = JSON.parse(data);
                    root.scoreText = j.text || "";
                    root.tooltipText = j.tooltip || "";
                    root.gameClass = j.class || "mlb-idle";
                    hasData = root.scoreText !== "";
                } catch (e) {
                    console.log("mlb parse error:", e, data);
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius_sm
        color: Qt.rgba(0, 0, 0, 0.4)
        border.color: root.gameClass === "mlb-live" ? Theme.connected : root.gameClass === "mlb-final" ? Theme.secondary : Theme.outline
        border.width: 1

        Text {
            id: scoreText
            anchors.centerIn: parent
            text: root.scoreText
            color: Theme.textColor
            font.pixelSize: 14
            font.family: "monospace"
        }

        ToolTip.visible: hoverHandler.hovered && root.tooltipText !== ""
        ToolTip.text: root.tooltipText
        ToolTip.delay: 400

        HoverHandler {
            id: hoverHandler
        }

        TapHandler {
            onTapped: Qt.openUrlExternally("https://www.mlb.com/scores")
        }
    }
}
