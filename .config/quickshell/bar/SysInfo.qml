import Quickshell
import Quickshell.Io
import QtQuick
import "../"

Capsule {
    id: root

    property var barWindow
    property bool expanded: false

    property string cpu:  "0%"
    property string mem:  "0%"
    property string disk: "0%"
    property string temp: "0°"
    property string cpuModel: ""
    property var cpuCores: []
    property bool cpuIsOpen: false
    property real cpuHoverWidth: 0  // grows to max seen width, never shrinks

    Timer {
        id: cpuCloseTimer
        interval: 250
        onTriggered: root.cpuIsOpen = false
    }

    Process {
        id: sysProcess
        command: [Qt.resolvedUrl("scripts/sys_info.sh").toString().replace("file://", "")]
        running: expanded
        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(";")
                if (parts.length < 6) return
                root.cpuModel = parts[0]
                root.cpu      = parts[1] + "%"
                root.mem      = parts[2] + "%"
                root.disk     = parts[3] + "%"
                root.temp     = parts[4] + "°"

                const coresStr = parts[5].trim().split(" ")
                const coresList = []
                for (let i = 0; i < coresStr.length; i++) {
                    const cParts = coresStr[i].split(":")
                    coresList.push({
                        index: i,
                        pct: parseInt(cParts[0]) || 0,
                        freq: parseInt(cParts[1]) || 0
                    })
                }
                root.cpuCores = coresList
            }
        }
    }

    TapHandler {
        onTapped: root.expanded = !root.expanded
    }

    contentItem: Row {
        id:               row
        spacing:          8

        // toggle icon
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           "󰞘"
            color:          Theme.textColor
            font.pixelSize: Theme.fontSize
            font.family:    Theme.nerdFont
        }

        // expandable section
        Item {
            anchors.verticalCenter: parent.verticalCenter
            height: Theme.barHeight
            width:  expanded ? innerRow.implicitWidth + 8 : 0
            clip:   true

            Behavior on width {
                NumberAnimation {
                    duration:  300
                    easing.type: Easing.InOutQuad
                }
            }

            Row {
                id:      innerRow
                height:  parent.height
                spacing: 8

                SysInfoChip {
                    id: cpuChip
                    label: ""
                    value: root.cpu
                    height: innerRow.height
                    width: Math.max(implicitWidth, root.cpuHoverWidth)
                    onImplicitWidthChanged: if (implicitWidth > root.cpuHoverWidth) root.cpuHoverWidth = implicitWidth

                    HoverHandler {
                        id: cpuHover
                        onHoveredChanged: {
                            if (hovered) {
                                cpuCloseTimer.stop()
                                root.cpuIsOpen = true
                            } else if (!cpuPopup.panelHovered) {
                                cpuCloseTimer.restart()
                            }
                        }
                    }
                }
                SysInfoChip { label: ""; value: root.mem  }
                SysInfoChip { label: "󰋊 "; value: root.disk }
                SysInfoChip { label: ""; value: root.temp }
            }
        }
    }

    Connections {
        target: cpuPopup
        function onPanelHoveredChanged() {
            if (cpuPopup.panelHovered) {
                cpuCloseTimer.stop()
            } else if (!cpuHover.hovered) {
                cpuCloseTimer.restart()
            }
        }
    }

    CpuPopup {
        id: cpuPopup
        barWindow: root.barWindow
        isOpen: root.cpuIsOpen
        targetItem: cpuChip
        cpuModel: root.cpuModel
        overallCpu: root.cpu
        cpuCores: root.cpuCores
    }
}
