import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

AnchoredPopup {
    id: root

    // Core data array: { index, pct, freq }
    property var cpuCores: []
    property string cpuModel: "Processor"
    property string overallCpu: "0%"

    // Header Section
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        // CPU icon
        Text {
            text: ""
            color: Theme.primary
            font.pixelSize: 18
            font.family: Theme.nerdFont
        }

        ColumnLayout {
            spacing: 2
            Text {
                text: root.cpuModel
                color: Theme.textColor
                font { pixelSize: 13; bold: true; family: Theme.font }
                Layout.maximumWidth: 500
                elide: Text.ElideRight
            }
            Text {
                text: "Overall Usage: " + root.overallCpu
                color: Theme.on_surface_variant
                font { pixelSize: 11; family: Theme.font }
            }
        }

        Item { Layout.fillWidth: true }
    }

    // Divider line
    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Theme.popupBorder
        opacity: 0.5
    }

    // Grid of CPU cores
    Grid {
        id: coresGrid
        columns: 4
        spacing: 10
        Layout.fillWidth: true

        Repeater {
            model: root.cpuCores

            delegate: Row {
                id: coreRow
                spacing: 8

                property int pct: modelData.pct
                property int freq: modelData.freq

                readonly property color pctColor: {
                    if (pct < 50) return Theme.battery_high
                    if (pct < 80) return Theme.battery_mid
                    return Theme.battery_low
                }

                // Core Number
                Text {
                    text: "C" + (modelData.index < 10 ? "0" + modelData.index : modelData.index)
                    font { family: Theme.nerdFont; pixelSize: 11 }
                    color: Theme.secondary
                    width: 24
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Percentage text
                Text {
                    text: pct + "%"
                    font { family: Theme.nerdFont; pixelSize: 11; bold: true }
                    color: coreRow.pctColor
                    width: 32
                    horizontalAlignment: Text.AlignRight
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Small usage progress bar
                Rectangle {
                    width: 50
                    height: 6
                    radius: 3
                    color: Theme.surface_container_high
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        width: (coreRow.pct / 100) * parent.width
                        height: parent.height
                        radius: 3
                        color: coreRow.pctColor
                    }
                }

                // Frequency Text
                Text {
                    text: freq < 1000 ? freq + "M" : (freq / 1000).toFixed(1) + "G"
                    font { family: Theme.nerdFont; pixelSize: 10 }
                    color: Theme.outline
                    width: 36
                    horizontalAlignment: Text.AlignRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
