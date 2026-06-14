// System tray (StatusNotifierItem) row for the bar.
// Left click activates, middle click is secondary activate, scroll forwards
// to the item, right click (or left click on menu-only items) opens the menu.
import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import qs.theme

Row {
    id: root
    property var barWindow

    spacing: 8
    visible: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: entry
            required property var modelData

            implicitWidth:  Theme.fontSize + 2
            implicitHeight: Theme.barHeight

            Image {
                anchors.centerIn: parent
                source:           entry.modelData.icon
                sourceSize.width:  Theme.fontSize
                sourceSize.height: Theme.fontSize
                width:  Theme.fontSize
                height: Theme.fontSize
                smooth: true
                visible: status === Image.Ready
                opacity: hover.hovered ? 1.0 : 0.85

                Behavior on opacity { NumberAnimation { duration: 120 } }
            }

            HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }

            TrayMenu {
                id: menu
                barWindow: root.barWindow
                trayItem:  entry.modelData
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton) {
                        entry.modelData.secondaryActivate()
                    } else if (mouse.button === Qt.RightButton
                               || entry.modelData.onlyMenu) {
                        if (entry.modelData.hasMenu) menu.openAt(entry)
                    } else {
                        entry.modelData.activate()
                    }
                }
                onWheel: wheel => entry.modelData.scroll(wheel.angleDelta.y, false)
            }
        }
    }
}
