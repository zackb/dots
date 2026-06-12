import QtQuick
import Quickshell.Widgets
import qs.theme
import qs.dock

// A single dock app: themed icon on a rounded hover background, launches on click.
Item {
    id: root

    // DesktopEntry id (from DockState.pinnedApps)
    property string appId: ""
    // resolved to a DesktopEntry
    property var entry: null

    property int iconSize: 44

    implicitWidth:  iconSize + 12
    implicitHeight: iconSize + 12

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Theme.radius_sm
        color: mouse.containsMouse ? Theme.surface_container_highest : "transparent"

        scale: mouse.pressed ? 0.92 : (mouse.containsMouse ? 1.06 : 1.0)
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
        Behavior on color { ColorAnimation { duration: 150 } }

        IconImage {
            id: icon
            anchors.centerIn: parent
            width:  root.iconSize
            height: root.iconSize

            source: {
                const ic = root.entry ? root.entry.icon : ""
                if (!ic || ic === "")
                    return "image://icon/application-x-executable"
                if (ic.startsWith("/"))
                    return "file://" + ic
                return "image://icon/" + ic
            }
            onStatusChanged: {
                if (status === Image.Error)
                    source = "image://icon/application-x-executable"
            }
        }
    }

    // Name tooltip on hover
    Rectangle {
        id: tip
        visible: opacity > 0
        opacity: mouse.containsMouse && root.entry ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }

        // place opposite the launch direction is unnecessary; sit above the icon
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: 6

        width:  tipText.implicitWidth + 16
        height: tipText.implicitHeight + 8
        radius: Theme.radius_sm
        color: Theme.popupBg
        border.color: Theme.popupBorder
        border.width: 1

        Text {
            id: tipText
            anchors.centerIn: parent
            text: root.entry ? root.entry.name : ""
            color: Theme.on_surface
            font { family: Theme.font; pixelSize: 12 }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: DockState.launch(root.appId)
    }
}
