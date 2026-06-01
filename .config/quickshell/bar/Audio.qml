import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import "../"

Rectangle {
    color:  Qt.alpha("#1e1e2e", 0.5)
    radius: height / 2
    height: 24
    width:  row.implicitWidth + 24

    // track the default audio sink
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    property PwNode sink:   Pipewire.defaultAudioSink
    property real  volume:  sink?.audio?.volume ?? 0
    property bool  muted:   sink?.audio?.muted  ?? false

    function volumeIcon() {
        if (muted || volume === 0) return "󰝟"
        if (volume < 0.33)        return ""
        if (volume < 0.66)        return ""
        return ""
    }

    Row {
        id:              row
        anchors.centerIn: parent
        spacing:         4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           volumeIcon()
            color:          muted ? Qt.alpha(Theme.textColor, 0.4) : Theme.textColor
            font.pixelSize: Theme.fontSize
            font.family:    Theme.nerdFont
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           Math.round(volume * 100) + "%"
            color:          Qt.alpha(Theme.textColor, muted ? 0.4 : 0.8)
            font.pixelSize: Theme.fontSize
            font.family:    Theme.font
        }

        TapHandler {
            onTapped:       sink.audio.muted = !sink.audio.muted
        }

        WheelHandler {
            onWheel: event => {
                const delta = event.angleDelta.y / 120
                sink.audio.volume = Math.max(0, Math.min(1.5, volume + delta * 0.05))
            }
        }
    }
}
