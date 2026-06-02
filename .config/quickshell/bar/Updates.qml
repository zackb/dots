import Quickshell
import QtQuick
import Quickshell.Io
import "../"

Rectangle {
    id: root
    color:  Qt.alpha("#1e1e2e", 0.5)
    radius: height / 2
    height: Theme.barHeight
    width:  row.implicitWidth + Theme.barHeight
    property string updateText: ""
    visible: updateText !== ""

    // re-fetch every 5 minutes
    Timer {
        interval: 300000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: updatesProcess.running = true
    }

    Process {
        id: updatesProcess
        running: false
        command: ["bash", Qt.resolvedUrl("updates.sh").toString().replace("file://", "")]
        stderr: SplitParser {
            onRead: data => console.log("updates stderr:", data)
        }

        stdout: SplitParser {
            onRead: data => {
                try {
                    const j = JSON.parse(data);
                    root.updateText = j.text ?? "";
                    // root.tooltipText = j.tooltip ?? "";
                } catch (e) {
                    console.log("updates parse error:", e, data);
                }
            }
        }
    }

    Row {
        id:              row
        anchors.centerIn: parent

        Text {
            id: updateLabel
            anchors.verticalCenter: parent.verticalCenter
            text:           root.updateText
            color:          Theme.textColor
            font.pixelSize: Theme.fontSize
            font.family:    Theme.nerdFont

        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: Quickshell.execDetached(["kitty", "/home/zackb/bin/installupdates.sh"])
        }
    }

}
