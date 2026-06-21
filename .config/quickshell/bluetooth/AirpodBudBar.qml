// AirpodBudBar.qml
// Small battery indicator for a single AirPod bud or case.
// Shows a filled bar and percentage text.

import QtQuick
import QtQuick.Layouts
import qs.theme

RowLayout {
    id: root

    required property string label
    required property int    pct      // 0-100, or -1 for unknown

    visible: pct >= 0
    spacing: 4

    Text {
        text:  root.label
        color: Theme.on_surface_variant
        font.pixelSize: Theme.font_size_sm
        font.bold: true
    }

    Rectangle {
        width:  52
        height: 7
        radius: 3
        color:  Theme.surface_container_high

        Rectangle {
            width:  Math.max(2, parent.width * (root.pct / 100))
            height: parent.height
            radius: 3
            color: {
                if (root.pct > 50) return Theme.battery_high
                if (root.pct > 20) return Theme.battery_mid
                return Theme.battery_low
            }

            Behavior on width { NumberAnimation { duration: 300 } }
            Behavior on color { ColorAnimation  { duration: 300 } }
        }
    }

    Text {
        text:  root.pct + "%"
        color: {
            if (root.pct > 50) return Theme.battery_high
            if (root.pct > 20) return Theme.battery_mid
            return Theme.battery_low
        }
        font.pixelSize: Theme.font_size_sm
    }
}
