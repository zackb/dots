import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import qs.theme
import qs.bar

Capsule {
    id: root

    property var barWindow
    property bool popupOpen: false
    property real maxWidth: 220                                       // set by Bar.qml budget
    readonly property real naturalTextWidth: songMarquee.naturalWidth // unconstrained song width

    // Pick the "active" player: prefer one that is playing, else the first
    // available. Recomputed whenever the player list or any play-state flips.
    property MprisPlayer player: selectPlayer()

    function selectPlayer() {
        const list = Mpris.players ? Mpris.players.values : []
        let fallback = null
        for (const p of list) {
            if (!p) continue
            if (!fallback) fallback = p
            if (p.isPlaying) return p
        }
        return fallback
    }

    Connections {
        target: Mpris.players
        function onValuesChanged() { root.player = root.selectPlayer() }
    }

    // Re-evaluate selection when any player's play state changes.
    Instantiator {
        model: Mpris.players
        delegate: Connections {
            required property MprisPlayer modelData
            target: modelData
            function onIsPlayingChanged() { root.player = root.selectPlayer() }
        }
    }

    visible: !!player
    // Close the popup if the player vanishes while it's open.
    onPlayerChanged: if (!player) popupOpen = false

    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onTapped: (eventPoint, button) => {
            if (button === Qt.MiddleButton)
                root.player?.togglePlaying()
            else
                root.popupOpen = !root.popupOpen
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (!root.player) return
            if (event.angleDelta.y < 0) {
                if (root.player.canGoNext) root.player.next()
            } else {
                if (root.player.canGoPrevious) root.player.previous()
            }
        }
    }

    contentItem: Row {
        id: row
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            // music note glyph; dims when paused
            text:           "󰝚"
            color:          root.player?.isPlaying ? Theme.textColor : Qt.alpha(Theme.textColor, 0.55)
            font.pixelSize: Theme.fontSize
            font.family:    Theme.nerdFont
        }

        Marquee {
            id: songMarquee
            anchors.verticalCenter: parent.verticalCenter
            maxWidth:      root.maxWidth
            hovered:       root.hovered
            text:          root.player
                           ? (root.player.trackTitle || "Unknown")
                             + (root.player.trackArtist ? "  —  " + root.player.trackArtist : "")
                           : ""
            color:         Theme.textColor
            fontFamily:    Theme.font
            fontPixelSize: Theme.fontSize
        }
    }

    MprisPopup {
        id: popup
        barWindow:  root.barWindow
        anchorItem: root
        player:     root.player
        isOpen:     root.popupOpen
        onRequestClose: root.popupOpen = false
    }
}
