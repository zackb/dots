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

    property int tempValue: 0
    property int memUsed:   0
    property int memTotal:  1
    property int memBuff:   0
    property int memAvail:  0
    property int diskUsed:  0
    property int diskTotal: 1
    property int diskAvail: 0

    property bool cpuIsOpen:  false
    property bool memIsOpen:  false
    property bool diskIsOpen: false
    property bool tempIsOpen: false

    property real cpuHoverWidth: 0

    Timer { id: cpuCloseTimer;  interval: 250; onTriggered: root.cpuIsOpen  = false }
    Timer { id: memCloseTimer;  interval: 250; onTriggered: root.memIsOpen  = false }
    Timer { id: diskCloseTimer; interval: 250; onTriggered: root.diskIsOpen = false }
    Timer { id: tempCloseTimer; interval: 250; onTriggered: root.tempIsOpen = false }

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
                root.tempValue = parseInt(parts[4]) || 0

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

                root.memUsed  = parseInt(parts[6])  || 0
                root.memTotal = parseInt(parts[7])  || 1
                root.memBuff  = parseInt(parts[8])  || 0
                root.memAvail = parseInt(parts[9])  || 0
                root.diskUsed  = parseInt(parts[10]) || 0
                root.diskTotal = parseInt(parts[11]) || 1
                root.diskAvail = parseInt(parts[12]) || 0
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
                    label: ""
                    value: root.cpu
                    height: innerRow.height
                    width: Math.max(implicitWidth, root.cpuHoverWidth)
                    onImplicitWidthChanged: if (implicitWidth > root.cpuHoverWidth) root.cpuHoverWidth = implicitWidth

                    HoverHandler {
                        id: cpuHover
                        onHoveredChanged: {
                            if (hovered) {
                                memPopup.closeNow();  root.memIsOpen  = false; memCloseTimer.stop()
                                diskPopup.closeNow(); root.diskIsOpen = false; diskCloseTimer.stop()
                                tempPopup.closeNow(); root.tempIsOpen = false; tempCloseTimer.stop()
                                cpuCloseTimer.stop()
                                root.cpuIsOpen = true
                            } else if (!cpuPopup.panelHovered) {
                                cpuCloseTimer.restart()
                            }
                        }
                    }
                }

                SysInfoChip {
                    id: memChip
                    label: ""
                    value: root.mem
                    height: innerRow.height

                    HoverHandler {
                        id: memHover
                        onHoveredChanged: {
                            if (hovered) {
                                cpuPopup.closeNow();  root.cpuIsOpen  = false; cpuCloseTimer.stop()
                                diskPopup.closeNow(); root.diskIsOpen = false; diskCloseTimer.stop()
                                tempPopup.closeNow(); root.tempIsOpen = false; tempCloseTimer.stop()
                                memCloseTimer.stop()
                                root.memIsOpen = true
                            } else if (!memPopup.panelHovered) {
                                memCloseTimer.restart()
                            }
                        }
                    }
                }

                SysInfoChip {
                    id: diskChip
                    label: "󰋊 "
                    value: root.disk
                    height: innerRow.height

                    HoverHandler {
                        id: diskHover
                        onHoveredChanged: {
                            if (hovered) {
                                cpuPopup.closeNow();  root.cpuIsOpen  = false; cpuCloseTimer.stop()
                                memPopup.closeNow();  root.memIsOpen  = false; memCloseTimer.stop()
                                tempPopup.closeNow(); root.tempIsOpen = false; tempCloseTimer.stop()
                                diskCloseTimer.stop()
                                root.diskIsOpen = true
                            } else if (!diskPopup.panelHovered) {
                                diskCloseTimer.restart()
                            }
                        }
                    }
                }

                SysInfoChip {
                    id: tempChip
                    label: ""
                    value: root.temp
                    height: innerRow.height

                    HoverHandler {
                        id: tempHover
                        onHoveredChanged: {
                            if (hovered) {
                                cpuPopup.closeNow();  root.cpuIsOpen  = false; cpuCloseTimer.stop()
                                memPopup.closeNow();  root.memIsOpen  = false; memCloseTimer.stop()
                                diskPopup.closeNow(); root.diskIsOpen = false; diskCloseTimer.stop()
                                tempCloseTimer.stop()
                                root.tempIsOpen = true
                            } else if (!tempPopup.panelHovered) {
                                tempCloseTimer.restart()
                            }
                        }
                    }
                }
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

    Connections {
        target: memPopup
        function onPanelHoveredChanged() {
            if (memPopup.panelHovered) {
                memCloseTimer.stop()
            } else if (!memHover.hovered) {
                memCloseTimer.restart()
            }
        }
    }

    Connections {
        target: diskPopup
        function onPanelHoveredChanged() {
            if (diskPopup.panelHovered) {
                diskCloseTimer.stop()
            } else if (!diskHover.hovered) {
                diskCloseTimer.restart()
            }
        }
    }

    Connections {
        target: tempPopup
        function onPanelHoveredChanged() {
            if (tempPopup.panelHovered) {
                tempCloseTimer.stop()
            } else if (!tempHover.hovered) {
                tempCloseTimer.restart()
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

    MemPopup {
        id: memPopup
        barWindow: root.barWindow
        isOpen: root.memIsOpen
        targetItem: memChip
        overallMem: root.mem
        memUsed:  root.memUsed
        memTotal: root.memTotal
        memBuff:  root.memBuff
        memAvail: root.memAvail
    }

    DiskPopup {
        id: diskPopup
        barWindow: root.barWindow
        isOpen: root.diskIsOpen
        targetItem: diskChip
        overallDisk: root.disk
        diskUsed:  root.diskUsed
        diskTotal: root.diskTotal
        diskAvail: root.diskAvail
    }

    TempPopup {
        id: tempPopup
        barWindow: root.barWindow
        isOpen: root.tempIsOpen
        targetItem: tempChip
        tempValue:  root.tempValue
        overallTemp: root.temp
    }
}
