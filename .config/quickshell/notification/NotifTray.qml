import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "../"

PanelWindow {
    id: tray
    visible: NotifServer.trayOpen
    implicitWidth: 400
    implicitHeight: contentCol.implicitHeight + 32
    color: "transparent"


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
        function toggle() { tray.visible = !tray.visible }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.popupBg
        radius: 16
        border.color: Theme.popupBorder
        border.width: 1

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                tray.visible = false
                event.accepted = true
            }
        }

        Column {
            id: contentCol
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 16
            }
            spacing: 8

            // Header
            Row {
                width: parent.width

                Text {
                    text: "Notifications"
                    color: Theme.on_surface
                    font.family: Theme.font
                    font.pixelSize: 16
                    font.weight: Font.Medium
                }

                Item {
                    width: parent.width - parent.children[0].implicitWidth - clearBtn.implicitWidth
                    height: 1
                }

                Text {
                    id: clearBtn
                    text: "Clear all"
                    color: Theme.primary
                    font.family: Theme.font
                    font.pixelSize: 13
                    TapHandler {
                        onTapped: NotifServer.history.clear()
                    }
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }

            // Empty state
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: NotifServer.history.count === 0
                text: "No notifications"
                color: Theme.on_surface_variant
                font.family: Theme.font
                font.pixelSize: 14
                topPadding: 12
                bottomPadding: 12
            }

            // Notification items
            Repeater {
                model: NotifServer.history

                delegate: Rectangle {
                    width: contentCol.width
                    height: itemCol.implicitHeight + 24
                    radius: 12
                    color: Theme.surface_container_highest

                    // Dismiss button
                    Text {
                        anchors {
                            top: parent.top
                            right: parent.right
                            margins: 10
                        }
                        text: "close"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 16
                        color: Theme.on_surface_variant
                        opacity: dismissHover.hovered ? 1.0 : 0.4

                        Behavior on opacity {
                            NumberAnimation { duration: 150 }
                        }

                        HoverHandler {
                            id: dismissHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: NotifServer.history.remove(index)
                        }
                    }

                    Column {
                        id: itemCol
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            margins: 12
                            topMargin: 12
                        }
                        spacing: 4

                        Text {
                            text: model.summary
                            color: Theme.on_surface
                            font.family: Theme.font
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            width: parent.width
                            elide: Text.ElideRight
                        }

                        Text {
                            text: model.body
                            color: Theme.on_surface_variant
                            font.family: Theme.font
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                            width: parent.width
                            visible: model.body !== ""
                        }

                        Text {
                            text: model.appName + " · " + Qt.formatTime(model.time, "h:mm ap")
                            color: Theme.on_surface_variant
                            font.family: Theme.font
                            font.pixelSize: 11
                            opacity: 0.7
                        }
                    }
                }
            }
        }
    }
}
