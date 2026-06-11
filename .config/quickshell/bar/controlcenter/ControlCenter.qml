import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import qs

PanelWindow {
    id: root

    IpcHandler {
        target: "controlcenter"
        function toggle() { root.isOpen = !root.isOpen }
        function open()   { root.isOpen = true  }
        function close()  { root.isOpen = false }
    }

    property var  barWindow: null
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
    screen: barWindow ? barWindow.screen : null
    visible: false

    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    property int panelY: barWindow ? (barWindow.margins.top + barWindow.height + 6) : 34

    Shortcut {
        sequence: "Escape"
        onActivated: root.isOpen = false
    }

    // Transparent backdrop — click anywhere outside the panel to close
    MouseArea {
        anchors.fill: parent
        onClicked: root.isOpen = false
        z: -1
    }

    // ── Panel ──────────────────────────────────────────────────────────
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

            // ── Header ────────────────────────────────────────────────
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

            // ── Volume ────────────────────────────────────────────────
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

            // ── Brightness ────────────────────────────────────────────
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

            // ── Session ───────────────────────────────────────────────
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
                          cmd: ["hyprctl", "dispatch", "exit"],      critical: false },
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
