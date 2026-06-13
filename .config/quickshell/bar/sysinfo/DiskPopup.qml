import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

AnchoredPopup {
    id: root
    minWidth: 230

    property int diskUsed:  0
    property int diskTotal: 1
    property int diskAvail: 0
    property string overallDisk: "0%"

    function toGB(mb) { return (mb / 1024).toFixed(1) }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: "󰋊"
            color: Theme.tertiary
            font.pixelSize: 18
            font.family: Theme.nerdFont
        }

        ColumnLayout {
            spacing: 2
            Text {
                text: "Storage"
                color: Theme.textColor
                font { pixelSize: 13; bold: true; family: Theme.font }
            }
            Text {
                text: "Usage: " + root.overallDisk
                color: Theme.on_surface_variant
                font { pixelSize: 11; family: Theme.font }
            }
        }

        Item { Layout.fillWidth: true }

        Text {
            text: root.toGB(root.diskUsed) + " / " + root.toGB(root.diskTotal) + " GB"
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

        readonly property real pct: root.diskTotal > 0 ? root.diskUsed / root.diskTotal : 0
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
            Text { text: "Used";      color: Theme.on_surface_variant; font { pixelSize: 11; family: Theme.font } }
            Item { Layout.fillWidth: true }
            Text { text: root.toGB(root.diskUsed)  + " GB"; color: Theme.textColor; font { pixelSize: 11; family: Theme.font } }
        }
        RowLayout {
            Layout.fillWidth: true
            Text { text: "Available"; color: Theme.on_surface_variant; font { pixelSize: 11; family: Theme.font } }
            Item { Layout.fillWidth: true }
            Text { text: root.toGB(root.diskAvail) + " GB"; color: Theme.textColor; font { pixelSize: 11; family: Theme.font } }
        }
        RowLayout {
            Layout.fillWidth: true
            Text { text: "Total";     color: Theme.on_surface_variant; font { pixelSize: 11; family: Theme.font } }
            Item { Layout.fillWidth: true }
            Text { text: root.toGB(root.diskTotal) + " GB"; color: Theme.textColor; font { pixelSize: 11; family: Theme.font } }
        }
    }
}
