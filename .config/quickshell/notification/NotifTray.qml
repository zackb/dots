import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.components
import qs.theme

PanelWindow {
    id: tray
    visible: false
    implicitWidth: 400
    implicitHeight: contentCol.implicitHeight + 32
    color: "transparent"

    // Cap the item list so a long history scrolls instead of growing the window
    // off the bottom of the screen.
    readonly property int maxListHeight: tray.screen
        ? Math.round(tray.screen.height * 0.6) : 420

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusiveZone: -1
    anchors { top: true; right: true }
    margins { top: Theme.barHeight + 8; right: 8 }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [tray]
        active: NotifServer.trayOpen
        onCleared: NotifServer.trayOpen = false
    }

    IpcHandler {
        target: "notiftray"
        function toggle() { NotifServer.trayOpen = !NotifServer.trayOpen }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: NotifServer.trayOpen = false
    }

    PopupPanel {
        id: panel
        anchors.fill: parent
        surface: tray
        open: NotifServer.trayOpen

        Column {
            id: contentCol
            anchors {
                top:    parent.top
                left:   parent.left
                right:  parent.right
                margins: 16
            }
            spacing: 8

            // Header
            RowLayout {
                width: parent.width

                Text {
                    text: "Notifications"
                    color: Theme.textColor
                    font { family: Theme.font; pixelSize: 15; bold: true }
                }

                Item { Layout.fillWidth: true }

                Text {
                    id: clearBtn
                    text: "Clear all"
                    color: Theme.primary
                    font { family: Theme.font; pixelSize: 13 }
                    TapHandler {
                        onTapped: {
                            NotifServer.history.clear()
                            NotifServer.trayOpen = false
                        }
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
            }

            // Empty state
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: NotifServer.history.count === 0
                text: "No notifications"
                color: Theme.on_surface_variant
                font { family: Theme.font; pixelSize: 14 }
                topPadding: 12
                bottomPadding: 12
            }

            // Notification items, capped at maxListHeight (scrolls past that).
            ScrollView {
                width: parent.width
                height: Math.min(listCol.implicitHeight, tray.maxListHeight)
                visible: NotifServer.history.count > 0
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                Column {
                    id: listCol
                    width: contentCol.width
                    spacing: 8

                    Repeater {
                        model: NotifServer.history

                        delegate: Rectangle {
                            width: listCol.width
                            height: textCol.implicitHeight + 24
                            radius: Theme.radius_sm
                            color: itemHover.hovered ? Theme.surface_container_highest : Theme.surface_container_high
                            border.color: Theme.popupBorder
                            border.width: 1

                            HoverHandler { id: itemHover }

                            Column {
                                id: textCol
                                anchors {
                                    top:         parent.top
                                    left:        parent.left
                                    right:       dismissBtn.left
                                    topMargin:   12
                                    leftMargin:  16
                                    rightMargin: 12
                                }
                                spacing: 2

                                Text {
                                    text: model.summary
                                    color: Theme.on_surface
                                    font { family: Theme.font; pixelSize: 13; bold: true }
                                    width: parent.width
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: model.body
                                    color: Theme.on_surface_variant
                                    font { family: Theme.font; pixelSize: 13 }
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                    visible: model.body !== ""
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: model.appName + " · " + Qt.formatTime(model.time, "h:mm ap")
                                    color: Theme.on_surface_variant
                                    font { family: Theme.font; pixelSize: Theme.font_size_sm }
                                    opacity: 0.7
                                }
                            }

                            Text {
                                id: dismissBtn
                                anchors {
                                    right:          parent.right
                                    verticalCenter: parent.verticalCenter
                                    rightMargin:    16
                                }
                                text: "close"
                                font { family: Theme.ligatureFont; pixelSize: 16 }
                                color: Theme.on_surface_variant
                                opacity: dismissHover.hovered ? 1.0 : 0.4
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                HoverHandler { id: dismissHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: NotifServer.history.remove(index) }
                            }
                        }
                    }
                }
            }
        }

    }
}
