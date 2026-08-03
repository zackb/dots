// Click-dismissed popup for switching default audio output / input devices.
// Replaces `hyprwat --audio`; selection goes straight to Pipewire.

import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

OverlayPopup {
    id: root

    panelWidth: 280
    contentSpacing: 4

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
