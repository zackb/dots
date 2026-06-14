// Click-dismissed popup for switching default audio output / input devices.
// Replaces `hyprwat --audio`; selection goes straight to Pipewire.

import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

OverlayPopup {
    id: root

    property Item anchorItem
    property int targetX: 0
    property int targetY: 0

    // Real output/input devices (no streams, no monitors).
    function _devices(wantSink) {
        const list = Pipewire.nodes ? Pipewire.nodes.values : []
        const out = []
        for (const n of list) {
            if (!n || n.isStream || !(n.type & PwNodeType.Audio)) continue
            if (wantSink) {
                if (n.isSink) out.push(n)
            } else if (!n.isSink && (n.type & PwNodeType.AudioSource)) {
                out.push(n)
            }
        }
        return out
    }

    readonly property var outputs: _devices(true)
    readonly property var inputs:  _devices(false)

    function _label(n) { return n ? (n.description || n.nickname || n.name) : "" }

    // Keep the listed nodes' properties live while open.
    PwObjectTracker { objects: root.outputs.concat(root.inputs) }

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
        width:  280
        height: content.implicitHeight + 24
        color:  Theme.popupBg
        radius: Theme.radius
        border.color: Theme.popupBorder
        border.width: 1

        transform: Translate { id: panelSlide; y: -10 }

        // Swallow clicks so they don't reach the backdrop and close the popup.
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

        // A single selectable device row.
        component DeviceRow: Rectangle {
            id: rowItem
            property var node
            property bool selected: false
            signal chosen()

            Layout.fillWidth: true
            implicitHeight: 30
            radius: Theme.radius_sm
            color: rowHover.hovered ? Theme.surface_container_high : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }

            RowLayout {
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                spacing: 8

                Text {
                    text: rowItem.selected ? "󰄬" : ""
                    color: Theme.primary
                    font { family: Theme.nerdFont; pixelSize: 13 }
                    Layout.preferredWidth: 14
                }
                Text {
                    Layout.fillWidth: true
                    text: root._label(rowItem.node)
                    color: rowItem.selected ? Theme.textColor : Theme.on_surface_variant
                    elide: Text.ElideRight
                    font { family: Theme.font; pixelSize: Theme.fontSize; bold: rowItem.selected }
                }
            }

            HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: rowItem.chosen() }
        }

        component SectionLabel: Text {
            color: Theme.outline
            font { pixelSize: 10; letterSpacing: 1.5; bold: true; family: Theme.font }
            Layout.topMargin: 2
        }

        ColumnLayout {
            id: content
            anchors {
                top: parent.top; left: parent.left; right: parent.right
                topMargin: 12; leftMargin: 12; rightMargin: 12
            }
            spacing: 4

            SectionLabel { text: "OUTPUT"; visible: root.outputs.length > 0 }
            Repeater {
                model: root.outputs
                delegate: DeviceRow {
                    required property var modelData
                    node: modelData
                    selected: modelData === Pipewire.defaultAudioSink
                    onChosen: {
                        Pipewire.preferredDefaultAudioSink = modelData
                        root.requestClose()
                    }
                }
            }

            SectionLabel { text: "INPUT"; visible: root.inputs.length > 0 }
            Repeater {
                model: root.inputs
                delegate: DeviceRow {
                    required property var modelData
                    node: modelData
                    selected: modelData === Pipewire.defaultAudioSource
                    onChosen: {
                        Pipewire.preferredDefaultAudioSource = modelData
                        root.requestClose()
                    }
                }
            }

            Text {
                visible: root.outputs.length === 0 && root.inputs.length === 0
                text: "No audio devices"
                color: Theme.outline
                font { family: Theme.font; pixelSize: Theme.fontSize }
                Layout.alignment: Qt.AlignHCenter
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
