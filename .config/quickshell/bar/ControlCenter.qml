import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "../"

PanelWindow {
    id: root

    IpcHandler {
        target: "controlcenter"
        function toggle() { root.isOpen = !root.isOpen }
        function open()   { root.isOpen = true  }
        function close()  { root.isOpen = false }
    }

    property bool isOpen: false

    // ── Audio ──────────────────────────────────────────────────────────
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    property PwNode sink: Pipewire.defaultAudioSink

    // ── Brightness ─────────────────────────────────────────────────────
    property int  brightness:    0
    property int  maxBrightness: 255
    property real brightnessPercent: maxBrightness > 0 ? brightness / maxBrightness : 0

    Process {
        id: brightWatcher
        running: false
        command: ["bash", "-c", `
            max=$(cat /sys/class/backlight/amdgpu_bl1/max_brightness)
            echo "max:$max"
            cat /sys/class/backlight/amdgpu_bl1/brightness
            while inotifywait -q -e modify /sys/class/backlight/amdgpu_bl1/brightness 2>/dev/null; do
                cat /sys/class/backlight/amdgpu_bl1/brightness
            done
        `]
        stdout: SplitParser {
            onRead: data => {
                if (data.startsWith("max:")) root.maxBrightness = parseInt(data.slice(4))
                else root.brightness = parseInt(data)
            }
        }
    }
    Component.onCompleted: brightWatcher.running = true

    // ── Window ─────────────────────────────────────────────────────────
    visible: false
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Shortcut {
        sequence: "Escape"
        onActivated: root.isOpen = false
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // ── Dim backdrop ───────────────────────────────────────────────────
    Rectangle {
        id: dimOverlay
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        opacity: 0
    }

    // ── Panel ──────────────────────────────────────────────────────────
    Rectangle {
        id: panel
        anchors.right:  parent.right
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        width: 320
        color: Theme.surface

        // Left edge border
        Rectangle {
            z: 2
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: 1
            color: Theme.popupBorder
        }

        transform: Translate { id: panelSlide; x: panel.width }

        ColumnLayout {
            id: contentCol
            width: panel.width
            spacing: 0

                // ── Header ────────────────────────────────────────────
                Item {
                    Layout.fillWidth: true
                    height: 64

                    // Accent stripe behind title
                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: 3
                        color: Theme.primary
                        opacity: 0.8
                    }

                    Text {
                        anchors {
                            left:           parent.left
                            leftMargin:     20
                            verticalCenter: parent.verticalCenter
                        }
                        text:  "Control Center"
                        color: Theme.on_surface
                        font { pixelSize: 17; bold: true; family: Theme.font }
                    }

                    // Close button
                    Rectangle {
                        id: closeBtn
                        anchors {
                            right:          parent.right
                            rightMargin:    16
                            verticalCenter: parent.verticalCenter
                        }
                        width: 30; height: 30; radius: 15
                        color: closeMa.containsMouse
                               ? Theme.surface_container_highest
                               : Theme.surface_container_high
                        border.color: Theme.popupBorder
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text:  "close"
                            font { family: Theme.ligatureFont; pixelSize: 18 }
                            color: Theme.on_surface_variant
                        }
                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    root.isOpen = false
                        }
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    height: 1; color: Theme.popupBorder; opacity: 0.6
                }

                // ── Volume ────────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin:    20
                    Layout.bottomMargin: 16
                    Layout.leftMargin:   20
                    Layout.rightMargin:  20
                    spacing: 14

                    Text {
                        text:  "VOLUME"
                        color: Theme.outline
                        font { pixelSize: 10; bold: true; letterSpacing: 1.5; family: Theme.font }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        // Mute toggle icon
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

                        // Volume slider
                        ControlSlider {
                            Layout.fillWidth: true
                            from: 0; to: 1.0
                            value:      root.sink?.audio?.volume ?? 0
                            trackColor: (root.sink?.audio?.muted ?? false)
                                        ? Theme.outline : Theme.primary
                            onMoved: (v) => { if (root.sink?.audio) root.sink.audio.volume = v }
                        }

                        // Percentage label
                        Text {
                            text: Math.round((root.sink?.audio?.volume ?? 0) * 100) + "%"
                            color: Theme.on_surface_variant
                            font { pixelSize: 12; family: Theme.font }
                            width: 38
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 20; Layout.rightMargin: 20
                    height: 1; color: Theme.popupBorder; opacity: 0.4
                }

                // ── Brightness ────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin:    20
                    Layout.bottomMargin: 16
                    Layout.leftMargin:   20
                    Layout.rightMargin:  20
                    spacing: 14

                    Text {
                        text:  "BRIGHTNESS"
                        color: Theme.outline
                        font { pixelSize: 10; bold: true; letterSpacing: 1.5; family: Theme.font }
                    }

                    RowLayout {
                        Layout.fillWidth: true
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
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 20; Layout.rightMargin: 20
                    height: 1; color: Theme.popupBorder; opacity: 0.4
                }

                // ── Session ───────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin:    20
                    Layout.bottomMargin: 24
                    Layout.leftMargin:   20
                    Layout.rightMargin:  20
                    spacing: 14

                    Text {
                        text:  "SESSION"
                        color: Theme.outline
                        font { pixelSize: 10; bold: true; letterSpacing: 1.5; family: Theme.font }
                    }

                    Grid {
                        columns:  3
                        spacing:  8
                        width:    panel.width - 40

                        Repeater {
                            model: [
                                { icon: "󰌾", label: "Lock",
                                  cmd: ["loginctl", "lock-session"],         critical: false },
                                { icon: "󰒲", label: "Sleep",
                                  cmd: ["systemctl", "suspend"],             critical: false },
                                { icon: "󰤄", label: "Hibernate",
                                  cmd: ["systemctl", "hibernate"],           critical: false },
                                { icon: "󰍃", label: "Logout",
                                  cmd: ["hyprctl", "dispatch", "exit"],      critical: false },
                                { icon: "󰑐", label: "Restart",
                                  cmd: ["systemctl", "reboot"],              critical: true  },
                                { icon: "󰐥", label: "Shutdown",
                                  cmd: ["systemctl", "poweroff"],            critical: true  },
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                property bool hov: false

                                // (panelWidth - 2×margin - 2×gap) / 3  =  (320-40-16)/3 = 88
                                width:  (panel.width - 40 - 16) / 3
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

                                Behavior on color       { ColorAnimation { duration: 120 } }
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
                }
            }

        // ── States & Transitions ──────────────────────────────────────
        states: [
            State {
                name: "open"
                when: root.isOpen
                PropertyChanges { target: panelSlide; x: 0 }
                PropertyChanges { target: dimOverlay; opacity: 1.0 }
            },
            State {
                name: "closed"
                when: !root.isOpen
                PropertyChanges { target: panelSlide; x: panel.width }
                PropertyChanges { target: dimOverlay; opacity: 0.0 }
            }
        ]

        transitions: [
            Transition {
                from: "closed"; to: "open"
                SequentialAnimation {
                    ScriptAction { script: root.visible = true }
                    ParallelAnimation {
                        NumberAnimation {
                            target: panelSlide; property: "x"
                            duration: 260; easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: dimOverlay; property: "opacity"
                            duration: 260
                        }
                    }
                }
            },
            Transition {
                from: "open"; to: "closed"
                SequentialAnimation {
                    ParallelAnimation {
                        NumberAnimation {
                            target: panelSlide; property: "x"
                            duration: 220; easing.type: Easing.InCubic
                        }
                        NumberAnimation {
                            target: dimOverlay; property: "opacity"
                            duration: 220
                        }
                    }
                    ScriptAction { script: root.visible = false }
                }
            }
        ]
    }

    // Click-outside: the area to the left of the panel
    MouseArea {
        x: 0; y: 0
        width:  root.width - panel.width
        height: root.height
        onClicked: root.isOpen = false
    }
}
