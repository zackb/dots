// Click-dismissed popup for switching the power-profiles-daemon profile.
// Replaces scripts/battery.sh + hyprwat + powerprofilesctl with native UPower.

import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

OverlayPopup {
    id: root

    panelWidth: 220
    contentSpacing: 4

    readonly property var profiles: {
        const arr = []
        if (PowerProfiles.hasPerformanceProfile)
            arr.push({ id: PowerProfile.Performance, glyph: "⚡", label: "Performance" })
        arr.push({ id: PowerProfile.Balanced,   glyph: "⚖", label: "Balanced" })
        arr.push({ id: PowerProfile.PowerSaver,  glyph: "▽", label: "Power Saver" })
        return arr
    }

    Repeater {
        model: root.profiles
        delegate: Rectangle {
            id: rowItem
            required property var modelData
            readonly property bool selected: modelData.id === PowerProfiles.profile

            Layout.fillWidth: true
            implicitHeight: 32
            radius: Theme.radius_sm
            color: rowHover.hovered ? Theme.surface_container_high : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }

            RowLayout {
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                spacing: 8

                Text {
                    text: rowItem.modelData.glyph
                    color: rowItem.selected ? Theme.primary : Theme.on_surface_variant
                    font { family: Theme.font; pixelSize: 14 }
                    Layout.preferredWidth: 16
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    Layout.fillWidth: true
                    text: rowItem.modelData.label
                    color: rowItem.selected ? Theme.textColor : Theme.on_surface_variant
                    font { family: Theme.font; pixelSize: Theme.fontSize; bold: rowItem.selected }
                }
                Text {
                    text: rowItem.selected ? "󰄬" : ""
                    color: Theme.primary
                    font { family: Theme.nerdFont; pixelSize: 13 }
                }
            }

            HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: {
                    PowerProfiles.profile = rowItem.modelData.id
                    root.requestClose()
                }
            }
        }
    }
}
