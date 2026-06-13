import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

AnchoredPopup {
    id: root
    minWidth: 200

    property int tempValue: 0
    property string overallTemp: "0°"

    readonly property color tempColor: tempValue < 60 ? Theme.battery_high : (tempValue < 80 ? Theme.battery_mid : Theme.battery_low)
    readonly property string tempStatus: tempValue < 60 ? "Normal" : (tempValue < 80 ? "Warm" : "Hot")

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: ""
            color: root.tempColor
            font.pixelSize: 18
            font.family: Theme.nerdFont
        }

        ColumnLayout {
            spacing: 2
            Text {
                text: "CPU Temperature"
                color: Theme.textColor
                font { pixelSize: 13; bold: true; family: Theme.font }
            }
            Text {
                text: root.tempStatus
                color: root.tempColor
                font { pixelSize: 11; family: Theme.font }
            }
        }

        Item { Layout.fillWidth: true }

        Text {
            text: root.overallTemp + "C"
            color: root.tempColor
            font { pixelSize: 20; bold: true; family: Theme.font }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Theme.popupBorder
        opacity: 0.5
    }

    // Temperature bar (scale: 0–100°C)
    Rectangle {
        Layout.fillWidth: true
        height: 6
        radius: 3
        color: Theme.surface_container_high

        Rectangle {
            width: Math.max(Math.min(root.tempValue / 100, 1.0) * parent.width, radius * 2)
            height: parent.height
            radius: 3
            color: root.tempColor
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Text { text: "0°C";   color: Theme.outline; font { pixelSize: 10; family: Theme.font } }
        Item { Layout.fillWidth: true }
        Text { text: "50°C";  color: Theme.outline; font { pixelSize: 10; family: Theme.font } }
        Item { Layout.fillWidth: true }
        Text { text: "100°C"; color: Theme.outline; font { pixelSize: 10; family: Theme.font } }
    }
}
