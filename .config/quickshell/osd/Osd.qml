import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import qs.backend
import qs.theme

Item {
    id: osdRoot

    // Audio
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    property PwNode sink: Pipewire.defaultAudioSink

    // Brightness — from the fenrizd backlight service (single shared inotify watch)
    property int  brightness:    Backend.backlight.brightness
    property int  maxBrightness: Backend.backlight.max
    property real brightnessPercent: maxBrightness > 0 ? brightness / maxBrightness : 0

    // OSD state
    property string osdMode:    "volume"   // "volume" | "brightness"
    property bool   osdVisible: false

    Timer {
        id: dismissTimer
        interval: 2000
        onTriggered: osdRoot.osdVisible = false
    }

    function showOsd(mode) {
        osdMode = mode
        osdVisible = true
        dismissTimer.restart()
    }

    // IPC
    IpcHandler {
        target: "osd"

        function volumeUp() {
            if (osdRoot.sink?.audio)
                osdRoot.sink.audio.volume = Math.min(1.0, (osdRoot.sink.audio.volume ?? 0) + 0.05)
            osdRoot.showOsd("volume")
        }
        function volumeDown() {
            if (osdRoot.sink?.audio)
                osdRoot.sink.audio.volume = Math.max(0, (osdRoot.sink.audio.volume ?? 0) - 0.05)
            osdRoot.showOsd("volume")
        }
        function mute() {
            if (osdRoot.sink?.audio)
                osdRoot.sink.audio.muted = !osdRoot.sink.audio.muted
            osdRoot.showOsd("volume")
        }
        function brightnessUp() {
            Quickshell.execDetached(["brightnessctl", "set", "5%+"])
            osdRoot.showOsd("brightness")
        }
        function brightnessDown() {
            Quickshell.execDetached(["brightnessctl", "set", "5%-"])
            osdRoot.showOsd("brightness")
        }
    }

    // Per-screen windows
    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            required property var modelData
            screen: modelData

            // Keep the surface mapped through the 220ms fade-out, then unmap so it
            // doesn't intercept pointer events
            Timer {
                id: hideDelay
                interval: 300
                running: !osdRoot.osdVisible
            }
            readonly property bool surfaceMapped: osdRoot.osdVisible || hideDelay.running

            visible: surfaceMapped

            WlrLayershell.layer:         WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors { bottom: true; left: true; right: true }
            color: "transparent"

            implicitWidth:  modelData.width
            implicitHeight: card.height + Theme.barHeight + 16 + 20

            property real volume: osdRoot.sink?.audio?.volume ?? 0
            property bool muted:  osdRoot.sink?.audio?.muted  ?? false

            function volumeIcon() {
                if (muted || volume === 0) return "󰝟"
                if (volume < 0.33)         return "󰕿"
                if (volume < 0.66)         return "󰖀"
                return                            "󰕾"
            }
            function brightnessIcon() {
                const p = osdRoot.brightnessPercent
                if (p < 0.33) return "󰃞"
                if (p < 0.66) return "󰃟"
                return                "󰃠"
            }

            // Card
            Rectangle {
                id: card
                width: 300
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom:           parent.bottom
                anchors.bottomMargin:     Theme.barHeight + 16

                height:       contentColumn.implicitHeight + 24
                radius:       Theme.radius
                color:        Theme.popupBg
                border.color: Theme.popupBorder
                border.width: 1

                opacity: osdRoot.osdVisible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }

                transform: Translate {
                    y: osdRoot.osdVisible ? 0 : 14
                    Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                }

                Row {
                    id: contentColumn
                    anchors {
                        top:    parent.top;   topMargin:   12
                        left:   parent.left;  leftMargin:  16
                        right:  parent.right; rightMargin: 16
                    }
                    spacing: 10

                    Text {
                        id:             iconText
                        anchors.verticalCenter: parent.verticalCenter
                        text:           osdRoot.osdMode === "volume" ? volumeIcon() : brightnessIcon()
                        font.family:    Theme.nerdFont
                        font.pixelSize: 18
                        color: (osdRoot.osdMode === "volume" && muted)
                               ? Qt.alpha(Theme.on_surface, 0.35)
                               : Theme.primary
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width:  parent.width - iconText.implicitWidth - pctLabel.width - parent.spacing * 2
                        height: 4
                        radius: 2
                        color:  Theme.surface_container_highest

                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            width: {
                                const pct = osdRoot.osdMode === "volume"
                                    ? Math.min(volume, 1.0)
                                    : osdRoot.brightnessPercent
                                return Math.max(0, pct) * parent.width
                            }
                            color: (osdRoot.osdMode === "volume" && muted)
                                   ? Theme.on_surface_variant
                                   : Theme.primary
                            Behavior on width { NumberAnimation { duration: 80;  easing.type: Easing.OutQuad } }
                            Behavior on color { ColorAnimation  { duration: 120 } }
                        }
                    }

                    Text {
                        id:    pctLabel
                        width: 36
                        anchors.verticalCenter: parent.verticalCenter
                        text: osdRoot.osdMode === "volume"
                              ? Math.round(volume * 100) + "%"
                              : Math.round(osdRoot.brightnessPercent * 100) + "%"
                        font.family:         Theme.font
                        font.pixelSize:      Theme.font_size_sm
                        color:               Theme.on_surface_variant
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }
}
