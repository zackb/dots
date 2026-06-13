import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

OverlayPopup {
    id: root

    property Item anchorItem
    property MprisPlayer player
    property int targetX: 0
    property int targetY: 0
    property bool panelHovered: panelHoverHandler.hovered

    // Guard against the INT64_MAX sentinel some players report when the real track length is unknown
    readonly property bool hasLength: player ? (player.length > 0 && player.length < 86400) : false

    function closeNow() {
        root.visible = false
        panel.opacity = 0
        panelSlide.y = -10
    }

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

    onIsOpenChanged: {
        if (!isOpen) return
        if (anchorItem) {
            const pos = anchorItem.mapToItem(null, 0, anchorItem.height)
            const marginTop = barWindow && barWindow.margins ? barWindow.margins.top : 0
            const screenW = barWindow && barWindow.width > 0 ? barWindow.width : 1920
            targetY = marginTop + barWindow.height + 6
            targetX = Math.max(8, Math.min(Math.round(pos.x), screenW - panel.width - 8))
        }
        if (root.player) root.player.positionChanged()
    }

    Rectangle {
        id: panel
        x: root.targetX
        y: root.targetY

        width:  320
        height: content.implicitHeight + 24
        // Smoothly absorb height changes when the track (and its seek bar /
        // metadata) swaps, instead of snapping. Only while already shown so the
        // open transition isn't animated.
        Behavior on height {
            enabled: root.visible
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }
        color:  Theme.popupBg
        radius: Theme.radius
        border.color: Theme.popupBorder
        border.width: 1

        // Slide-down on open via transform, so x/y stay pinned to the target.
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

        HoverHandler { id: panelHoverHandler }

        Shortcut {
            sequence: "Escape"
            enabled: root.isOpen
            onActivated: root.requestClose()
        }

        ColumnLayout {
            id: content
            anchors {
                top: parent.top; left: parent.left; right: parent.right
                topMargin: 12; leftMargin: 12; rightMargin: 12
            }
            spacing: 10

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
