import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import "../"

Capsule {
    id: root

    // track the default audio sink
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    property PwNode sink:   Pipewire.defaultAudioSink
    property real  volume:  sink?.audio?.volume ?? 0
    property bool  muted:   sink?.audio?.muted  ?? false

    function volumeIcon() {
        if (muted || volume === 0) return "󰝟"  // muted
        if (volume < 0.33)        return "󰕿"  // low
        if (volume < 0.66)        return "󰖀"  // medium
        return                           "󰕾"  // high
    }

    TapHandler {
        onTapped:       sink.audio.muted = !sink.audio.muted
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const delta = -event.angleDelta.y / 120
            if (delta < 0 && volume <= 0) return
            if (delta > 0 && volume >= 1) return
            sink.audio.volume = Math.max(0, Math.min(1.5, volume + delta * 0.05))
        }
    }

    contentItem: Row {
        id:              row
        spacing:         4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           volumeIcon()
            color:          muted ? Qt.alpha(Theme.textColor, 0.4) : Theme.textColor
            font.pixelSize: Theme.fontSize
            font.family:    Theme.nerdFont
        }

        Text {
            visible:       root.hovered
            anchors.verticalCenter: parent.verticalCenter
            text:           Math.round(volume * 100) + "%"
            color:          Qt.alpha(Theme.textColor, muted ? 0.4 : 0.8)
            font.pixelSize: Theme.fontSize
            font.family:    Theme.font
        }
    }
}
