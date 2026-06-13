import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

AnchoredPopup {
    id: root
    minWidth: 230

    property int memUsed:  0
    property int memTotal: 1
    property int memBuff:  0
    property int memAvail: 0
    property string overallMem: "0%"

    function toGB(mb) { return (mb / 1024).toFixed(1) }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: ""
            color: Theme.secondary
            font.pixelSize: 18
            font.family: Theme.nerdFont
        }

        ColumnLayout {
            spacing: 2
            Text {
                text: "Memory"
                color: Theme.textColor
                font { pixelSize: 13; bold: true; family: Theme.font }
            }
            Text {
                text: "Usage: " + root.overallMem
                color: Theme.on_surface_variant
                font { pixelSize: 11; family: Theme.font }
            }
        }

        Item { Layout.fillWidth: true }

        Text {
            text: root.toGB(root.memUsed) + " / " + root.toGB(root.memTotal) + " GB"
            color: Theme.textColor
            font { pixelSize: 12; family: Theme.font }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Theme.popupBorder
        opacity: 0.5
    }

    Rectangle {
        Layout.fillWidth: true
        height: 6
        radius: 3
        color: Theme.surface_container_high

        readonly property real pct: root.memTotal > 0 ? root.memUsed / root.memTotal : 0
        readonly property color fillColor: pct < 0.5 ? Theme.battery_high : (pct < 0.8 ? Theme.battery_mid : Theme.battery_low)

        Rectangle {
            width: parent.pct * parent.width
            height: parent.height
            radius: 3
            color: parent.fillColor
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            Text { text: "Used";       color: Theme.on_surface_variant; font { pixelSize: 11; family: Theme.font } }
            Item { Layout.fillWidth: true }
            Text { text: root.toGB(root.memUsed)  + " GB"; color: Theme.textColor; font { pixelSize: 11; family: Theme.font } }
        }
        RowLayout {
            Layout.fillWidth: true
            Text { text: "Available";  color: Theme.on_surface_variant; font { pixelSize: 11; family: Theme.font } }
            Item { Layout.fillWidth: true }
            Text { text: root.toGB(root.memAvail) + " GB"; color: Theme.textColor; font { pixelSize: 11; family: Theme.font } }
        }
        RowLayout {
            Layout.fillWidth: true
            Text { text: "Buff/Cache"; color: Theme.on_surface_variant; font { pixelSize: 11; family: Theme.font } }
            Item { Layout.fillWidth: true }
            Text { text: root.toGB(root.memBuff)  + " GB"; color: Theme.textColor; font { pixelSize: 11; family: Theme.font } }
        }
        RowLayout {
            Layout.fillWidth: true
            Text { text: "Total";      color: Theme.on_surface_variant; font { pixelSize: 11; family: Theme.font } }
            Item { Layout.fillWidth: true }
            Text { text: root.toGB(root.memTotal) + " GB"; color: Theme.textColor; font { pixelSize: 11; family: Theme.font } }
        }
    }
}
