// Click-dismissed popup for switching the power-profiles-daemon profile.
// Replaces scripts/battery.sh + hyprwat + powerprofilesctl with native UPower.

import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

OverlayPopup {
    id: root

    property Item anchorItem
    property int targetX: 0
    property int targetY: 0

    readonly property var profiles: {
        const arr = []
        if (PowerProfiles.hasPerformanceProfile)
            arr.push({ id: PowerProfile.Performance, glyph: "⚡", label: "Performance" })
        arr.push({ id: PowerProfile.Balanced,   glyph: "⚖", label: "Balanced" })
        arr.push({ id: PowerProfile.PowerSaver,  glyph: "▽", label: "Power Saver" })
        return arr
    }

    onIsOpenChanged: {
        if (!isOpen || !anchorItem) return
        const pos = anchorItem.mapToItem(null, 0, anchorItem.height)
        const marginTop = barWindow && barWindow.margins ? barWindow.margins.top : 0
        const screenW = barWindow && barWindow.width > 0 ? barWindow.width : 1920
        targetY = marginTop + barWindow.height + 6
        targetX = Math.max(8, Math.min(Math.round(pos.x), screenW - panel.width - 8))
    }

    Rectangle {
        id: panel
        x: root.targetX
        y: root.targetY
        width:  220
        height: content.implicitHeight + 24
        color:  Theme.popupBg
        radius: Theme.radius
        border.color: Theme.popupBorder
        border.width: 1

        transform: Translate { id: panelSlide; y: -10 }

        MouseArea { anchors.fill: parent }

        Rectangle {
            anchors { fill: parent; margins: -1 }
            color: "transparent"
            border.color: Qt.rgba(0, 0, 0, 0.4)
            border.width: 1
            radius: Theme.radius + 1
            z: -1
        }

        Shortcut {
            sequence: "Escape"
            enabled: root.isOpen
            onActivated: root.requestClose()
        }

        ColumnLayout {
            id: content
            anchors {
                top: parent.top; left: parent.left; right: parent.right
                topMargin: 12; leftMargin: 12; rightMargin: 12
            }
            spacing: 4

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

        states: [
            State { name: "open";   when: root.isOpen;  PropertyChanges { target: panel; opacity: 1.0 } PropertyChanges { target: panelSlide; y: 0   } },
            State { name: "closed"; when: !root.isOpen; PropertyChanges { target: panel; opacity: 0.0 } PropertyChanges { target: panelSlide; y: -10 } }
        ]
        transitions: [
            Transition {
                from: "closed"; to: "open"
                SequentialAnimation {
                    ScriptAction { script: root.visible = true }
                    ParallelAnimation {
                        NumberAnimation { target: panel;      property: "opacity"; duration: 180; easing.type: Easing.OutQuad }
                        NumberAnimation { target: panelSlide; property: "y";       duration: 180; easing.type: Easing.OutQuad }
                    }
                }
            },
            Transition {
                from: "open"; to: "closed"
                SequentialAnimation {
                    ParallelAnimation {
                        NumberAnimation { target: panel;      property: "opacity"; duration: 150; easing.type: Easing.OutQuad }
                        NumberAnimation { target: panelSlide; property: "y";       duration: 150; easing.type: Easing.OutQuad }
                    }
                    ScriptAction { script: root.visible = false }
                }
            }
        ]
    }
}
