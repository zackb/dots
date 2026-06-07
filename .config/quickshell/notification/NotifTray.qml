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
        color: Theme.surface
        radius: Theme.radius
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
                    height: textCol.implicitHeight + 24
                    radius: Theme.radius_sm
                    color: itemHover.hovered ? Theme.surface_container_highest : Theme.surface_container_high
                    border.color: Theme.popupBorder
                    border.width: 1

                    HoverHandler {
                        id: itemHover
                    }

                    Column {
                        id: textCol
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: dismissBtn.left
                            topMargin: 12
                            leftMargin: 16
                            rightMargin: 12
                        }
                        spacing: 2

                        Text {
                            text: model.summary
                            color: Theme.on_surface
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.bold: true
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
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Text {
                            text: model.appName + " · " + Qt.formatTime(model.time, "h:mm ap")
                            color: Theme.on_surface_variant
                            font.family: Theme.font
                            font.pixelSize: Theme.font_size_sm
                            opacity: 0.7
                        }
                    }

                    Text {
                        id: dismissBtn
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            rightMargin: 16
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
                }
            }
        }
    }
}
