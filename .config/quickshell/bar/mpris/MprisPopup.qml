import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

OverlayPopup {
    id: root

    property MprisPlayer player

    panelWidth: 320
    contentSpacing: 10

    // Guard against the INT64_MAX sentinel some players report when the real track length is unknown
    readonly property bool hasLength: player ? (player.length > 0 && player.length < 86400) : false

    function fmt(seconds) {
        if (!seconds || seconds < 0) return "0:00"
        const s = Math.floor(seconds)
        const m = Math.floor(s / 60)
        return m + ":" + String(s % 60).padStart(2, "0")
    }

    // Poll position only while open and playing
    Timer {
        running: root.isOpen && (root.player?.isPlaying ?? false) && root.hasLength
        interval: 1000
        repeat: true
        onTriggered: if (root.player) root.player.positionChanged()
    }

    onIsOpenChanged: if (isOpen && root.player) root.player.positionChanged()

    // Art + metadata
    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            radius: Theme.radius_sm
            color: Theme.surface_container_high
            clip: true

            Image {
                id: art
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: "󰝚"
                color: Theme.on_surface_variant
                font.family: Theme.nerdFont
                font.pixelSize: 28
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.player?.trackTitle || "Nothing playing"
                color: Theme.textColor
                elide: Text.ElideRight
                font { family: Theme.font; pixelSize: 14; bold: true }
            }
            Text {
                Layout.fillWidth: true
                visible: !!(root.player?.trackArtist)
                text: root.player?.trackArtist ?? ""
                color: Theme.on_surface_variant
                elide: Text.ElideRight
                font { family: Theme.font; pixelSize: 12 }
            }
            Text {
                Layout.fillWidth: true
                visible: !!(root.player?.trackAlbum)
                text: root.player?.trackAlbum ?? ""
                color: Qt.alpha(Theme.on_surface_variant, 0.7)
                elide: Text.ElideRight
                font { family: Theme.font; pixelSize: 11 }
            }
        }
    }

    // Seek bar
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.hasLength
        spacing: 3

        Rectangle {
            id: seekTrack
            Layout.fillWidth: true
            height: 4
            radius: 2
            color: Theme.surface_container_high

            Rectangle {
                height: parent.height
                radius: parent.radius
                color: Theme.primary
                width: root.hasLength
                       ? parent.width * Math.min(1, (root.player.position / root.player.length))
                       : 0
            }

            TapHandler {
                enabled: root.player?.canSeek ?? false
                onTapped: eventPoint => {
                    if (!root.player || !root.hasLength) return
                    const frac = Math.max(0, Math.min(1, eventPoint.position.x / seekTrack.width))
                    root.player.position = frac * root.player.length
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: root.fmt(root.player?.position ?? 0)
                color: Theme.on_surface_variant
                font { family: Theme.font; pixelSize: 10 }
            }
            Item { Layout.fillWidth: true }
            Text {
                text: root.hasLength ? root.fmt(root.player.length) : "--:--"
                color: Theme.on_surface_variant
                font { family: Theme.font; pixelSize: 10 }
            }
        }
    }

    // Transport controls
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 18

        component CtlButton: Rectangle {
            id: btn
            property string glyph: ""
            property bool active: true
            signal activated()
            width: 34; height: 34; radius: 17
            color: hh.hovered && active ? Theme.surface_container_high : "transparent"
            opacity: active ? 1.0 : 0.35
            Behavior on color { ColorAnimation { duration: 100 } }
            Text {
                anchors.centerIn: parent
                text: btn.glyph
                color: Theme.textColor
                font.family: Theme.nerdFont
                font.pixelSize: btn.width >= 40 ? 22 : 18
            }
            HoverHandler { id: hh; cursorShape: btn.active ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler { enabled: btn.active; onTapped: btn.activated() }
        }

        CtlButton {
            glyph: "󰒮"
            active: root.player?.canGoPrevious ?? false
            onActivated: root.player?.previous()
        }
        CtlButton {
            width: 44; height: 44; radius: 22
            glyph: root.player?.isPlaying ? "󰏤" : "󰐊"
            active: root.player?.canTogglePlaying ?? false
            onActivated: root.player?.togglePlaying()
        }
        CtlButton {
            glyph: "󰒭"
            active: root.player?.canGoNext ?? false
            onActivated: root.player?.next()
        }
    }
}
