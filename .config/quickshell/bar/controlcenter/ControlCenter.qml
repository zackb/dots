import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import qs.backend
import qs.components
import qs.theme
import qs.dock

OverlayPopup {
    id: root

    onRequestClose: root.isOpen = false

    IpcHandler {
        target: "controlcenter"
        function toggle() { root.isOpen = !root.isOpen }
        function open()   { root.isOpen = true  }
        function close()  { root.isOpen = false }
    }

    // Audio
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    property PwNode sink: Pipewire.defaultAudioSink

    // Brightness
    property int  brightness:    Backend.backlight.brightness
    property int  maxBrightness: Backend.backlight.max
    property real brightnessPercent: maxBrightness > 0 ? brightness / maxBrightness : 0

    property int panelY: barWindow ? (barWindow.margins.top + barWindow.height + 6) : 34

    Shortcut {
        sequence: "Escape"
        onActivated: root.isOpen = false
    }

    // Panel
    Rectangle {
        id: panel
        anchors.right:       parent.right
        anchors.rightMargin: 8
        y:      root.panelY
        width:  320
        height: contentCol.implicitHeight + 24
        color:  Theme.popupBg
        radius: Theme.radius
        border.color: Theme.popupBorder
        border.width: 1

        // Slide in from the right via transform
        transform: Translate { id: panelSlide; x: panel.width }

        // Drop shadow
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            color: "transparent"
            border.color: Qt.rgba(0, 0, 0, 0.4)
            border.width: 1
            radius: Theme.radius + 1
            z: -1
        }

        // Swallow clicks so they don't reach the backdrop MouseArea
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: contentCol
            anchors {
                top:         parent.top
                left:        parent.left
                right:       parent.right
                topMargin:   12
                leftMargin:  16
                rightMargin: 16
            }
            spacing: 0

            // Header
            Text {
                text:  "Control Center"
                color: Theme.textColor
                font { pixelSize: 15; bold: true; family: Theme.font }
                Layout.bottomMargin: 10
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.bottomMargin: 14
                height: 1; color: Theme.popupBorder; opacity: 0.6
            }

            // Volume
            Text {
                text:  "VOLUME"
                color: Theme.outline
                font { pixelSize: 10; bold: true; letterSpacing: 1.5; family: Theme.font }
                Layout.bottomMargin: 10
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 14
                spacing: 14

                Text {
                    text: {
                        const v = root.sink?.audio?.volume ?? 0
                        const m = root.sink?.audio?.muted  ?? false
                        if (m || v === 0) return "󰝟"
                        if (v < 0.33)     return "󰕿"
                        if (v < 0.66)     return "󰖀"
                        return "󰕾"
                    }
                    color: (root.sink?.audio?.muted ?? false)
                           ? Qt.alpha(Theme.primary, 0.35)
                           : Theme.primary
                    font { pixelSize: 22; family: Theme.nerdFont }
                    Behavior on color { ColorAnimation { duration: 120 } }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            if (root.sink?.audio)
                                root.sink.audio.muted = !root.sink.audio.muted
                        }
                    }
                }

                ControlSlider {
                    Layout.fillWidth: true
                    from: 0; to: 1.0
                    value:      root.sink?.audio?.volume ?? 0
                    trackColor: (root.sink?.audio?.muted ?? false)
                                ? Theme.outline : Theme.primary
                    onMoved: (v) => { if (root.sink?.audio) root.sink.audio.volume = v }
                }

                Text {
                    text: Math.round((root.sink?.audio?.volume ?? 0) * 100) + "%"
                    color: Theme.on_surface_variant
                    font { pixelSize: 12; family: Theme.font }
                    width: 38
                    horizontalAlignment: Text.AlignRight
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.bottomMargin: 14
                height: 1; color: Theme.popupBorder; opacity: 0.4
            }

            // Brightness
            Text {
                text:  "BRIGHTNESS"
                color: Theme.outline
                font { pixelSize: 10; bold: true; letterSpacing: 1.5; family: Theme.font }
                Layout.bottomMargin: 10
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 14
                spacing: 14

                Text {
                    text: {
                        const p = root.brightnessPercent
                        if (p < 0.33) return "󰃞"
                        if (p < 0.66) return "󰃟"
                        return "󰃠"
                    }
                    color: Theme.primary
                    font { pixelSize: 22; family: Theme.nerdFont }
                }

                ControlSlider {
                    Layout.fillWidth: true
                    from:  1
                    to:    root.maxBrightness > 0 ? root.maxBrightness : 255
                    value: root.brightness
                    onMoved: (v) => Quickshell.execDetached(
                        ["brightnessctl", "set", Math.round(v).toString()])
                }

                Text {
                    text: Math.round(root.brightnessPercent * 100) + "%"
                    color: Theme.on_surface_variant
                    font { pixelSize: 12; family: Theme.font }
                    width: 38
                    horizontalAlignment: Text.AlignRight
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.bottomMargin: 14
                height: 1; color: Theme.popupBorder; opacity: 0.4
            }

            // Session
            Text {
                text:  "SESSION"
                color: Theme.outline
                font { pixelSize: 10; bold: true; letterSpacing: 1.5; family: Theme.font }
                Layout.bottomMargin: 10
            }

            Grid {
                id: sessionGrid
                columns: 3
                spacing: 8
                Layout.fillWidth: true
                Layout.bottomMargin: 4

                Repeater {
                    model: [
                        { icon: "󰌾", label: "Lock",
                          cmd: ["loginctl", "lock-session"],         critical: false },
                        { icon: "󰒲", label: "Sleep",
                          cmd: ["systemctl", "suspend"],             critical: false },
                        { icon: "󰤄", label: "Hibernate",
                          cmd: ["systemctl", "hibernate"],           critical: false },
                        { icon: "󰍃", label: "Logout",
                          cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"], critical: false },
                        { icon: "󰑐", label: "Restart",
                          cmd: ["systemctl", "reboot"],              critical: true  },
                        { icon: "󰐥", label: "Shutdown",
                          cmd: ["systemctl", "poweroff"],            critical: true  },
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        property bool hov: false

                        width:  (sessionGrid.width - sessionGrid.spacing * 2) / 3
                        height: 72
                        radius: Theme.radius_sm
                        color:  hov
                            ? (modelData.critical
                               ? Qt.alpha(Theme.critical, 0.15)
                               : Theme.surface_container_highest)
                            : Theme.surface_container_high
                        border.color: (hov && modelData.critical)
                            ? Qt.alpha(Theme.critical, 0.5)
                            : Theme.popupBorder
                        border.width: 1

                        Behavior on color        { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text:  modelData.icon
                                font { family: Theme.nerdFont; pixelSize: 24 }
                                color: (hov && modelData.critical)
                                       ? Theme.critical : Theme.on_surface
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text:  modelData.label
                                font { family: Theme.font; pixelSize: 11 }
                                color: (hov && modelData.critical)
                                       ? Theme.critical : Theme.on_surface_variant
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                        }

                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                            onHoveredChanged: parent.hov = hovered
                        }
                        TapHandler {
                            onTapped: {
                                root.isOpen = false
                                Qt.callLater(() => Quickshell.execDetached(modelData.cmd))
                            }
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 14
                Layout.bottomMargin: 14
                height: 1; color: Theme.popupBorder; opacity: 0.4
            }

            // Dock
            Text {
                text:  "DOCK"
                color: Theme.outline
                font { pixelSize: 10; bold: true; letterSpacing: 1.5; family: Theme.font }
                Layout.bottomMargin: 10
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: DockState.enabled ? 12 : 4
                spacing: 12

                Text {
                    text: "Enable dock"
                    color: Theme.on_surface
                    font { pixelSize: 12; family: Theme.font }
                }

                Item { Layout.fillWidth: true }

                // ON/OFF pill toggle
                Rectangle {
                    width: 44; height: 24; radius: 12
                    color: DockState.enabled ? Theme.primary : Theme.surface_container_high
                    border.color: Theme.surface_container_highest
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: DockState.enabled ? "ON" : "OFF"
                        color: DockState.enabled ? Theme.on_primary : Theme.outline
                        font { pixelSize: 10; bold: true; family: Theme.font }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: DockState.enabled = !DockState.enabled
                    }
                }
            }

            // Position selector (only meaningful while enabled)
            RowLayout {
                id: dockPositions
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                spacing: 8
                visible: DockState.enabled

                Repeater {
                    model: DockState.positions

                    delegate: Rectangle {
                        required property string modelData
                        readonly property bool active: DockState.position === modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: Theme.radius_sm
                        color: active ? Theme.primary : Theme.surface_container_high
                        border.color: active ? Theme.primary : Theme.popupBorder
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                            color: parent.active ? Theme.on_primary : Theme.on_surface_variant
                            font { pixelSize: 11; family: Theme.font }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: DockState.position = modelData
                        }
                    }
                }
            }
        }

        states: [
            State {
                name: "open"
                when: root.isOpen
                PropertyChanges { target: panelSlide; x: 0 }
                PropertyChanges { target: panel; opacity: 1.0 }
            },
            State {
                name: "closed"
                when: !root.isOpen
                PropertyChanges { target: panelSlide; x: panel.width }
                PropertyChanges { target: panel; opacity: 0.0 }
            }
        ]

        transitions: [
            Transition {
                from: "closed"; to: "open"
                SequentialAnimation {
                    ScriptAction { script: root.visible = true }
                    ParallelAnimation {
                        NumberAnimation { target: panelSlide; property: "x";       duration: 260; easing.type: Easing.OutCubic }
                        NumberAnimation { target: panel;      property: "opacity"; duration: 260 }
                    }
                }
            },
            Transition {
                from: "open"; to: "closed"
                SequentialAnimation {
                    ParallelAnimation {
                        NumberAnimation { target: panelSlide; property: "x";       duration: 220; easing.type: Easing.InCubic }
                        NumberAnimation { target: panel;      property: "opacity"; duration: 220 }
                    }
                    ScriptAction { script: root.visible = false }
                }
            }
        ]
    }
}
