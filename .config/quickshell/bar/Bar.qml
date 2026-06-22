import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.bar.clock
import qs.bar.sysinfo
import qs.bar.mpris

PanelWindow {
    id: root
    property var controlCenterRef: null
    Component.onCompleted: {
        if (controlCenterRef && !controlCenterRef.barWindow)
            controlCenterRef.barWindow = root
    }

    anchors {
        top:   true
        left:  true
        right: true
    }
    margins {
        top: 4
        bottom: 2
    }

    WlrLayershell.layer:     WlrLayer.Bottom
    WlrLayershell.namespace: "zbar"

    implicitHeight: 24

    color:  "transparent"
    onScreenChanged: {
        color = "transparent"
    }

    Rectangle {
        id:           barBody
        anchors.fill: parent
        color:        Qt.rgba(0.0, 0.0, 0.0, 0.0)

        // Left section may grow up to clockGap before the centered Clock; title
        // and song share the leftover, Workspaces always stays full.
        readonly property int  leftStart: 8     // = leftSection.leftMargin
        readonly property int  clockGap:  12
        readonly property int  capsuleOverhead:    46  // icon + spacing + padding, per capsule
        readonly property int  sepSpacingOverhead: 18  // separators + Row spacings

        readonly property real maxLeftWidth:  centerSection.x - leftStart - clockGap
        readonly property real capsuleBudget: maxLeftWidth - workspaces.width - sepSpacingOverhead
        readonly property int  visibleFlex:   (activeWindow.visible ? 1 : 0)
                                            + (nowPlaying.visible   ? 1 : 0)
        readonly property real textTotal: capsuleBudget - capsuleOverhead * visibleFlex
        readonly property real titleNat:  activeWindow.visible ? activeWindow.naturalTextWidth : 0
        readonly property real songNat:   nowPlaying.visible   ? nowPlaying.naturalTextWidth   : 0

        // Shorter widget keeps full width, longer takes the slack, even half when both overflow.
        function flexShare(selfNat, otherNat) {
            if (selfNat + otherNat <= textTotal) return selfNat
            const half = textTotal / 2
            if (otherNat <= half) return textTotal - otherNat
            if (selfNat  <= half) return selfNat
            return half
        }
        readonly property real titleMax: Math.max(0, flexShare(titleNat, songNat))
        readonly property real songMax:  Math.max(0, flexShare(songNat, titleNat))

        // Left
        Row {
            id:               leftSection
            anchors {
                left:           parent.left
                verticalCenter: parent.verticalCenter
                leftMargin:     barBody.leftStart
            }
            spacing: 4

            Workspaces { id: workspaces }
            BarSeparator {
                visible: activeWindow.visible
            }
            ActiveWindow {
                id: activeWindow
                maxWidth: barBody.titleMax
            }
            BarSeparator {
                visible: nowPlaying.visible
            }
            Mpris {
                id: nowPlaying
                barWindow: root
                maxWidth:  barBody.songMax
            }
        }

        // Center
        Row {
            id: centerSection
            anchors.centerIn: parent
            spacing: 8

            Clock { barWindow: root }
        }

        // Right
        Row {
            id: rightSection
            anchors {
                right:          parent.right
                verticalCenter: parent.verticalCenter
                rightMargin:    18
            }
            spacing: 6

            Updates {}
            Audio { barWindow: root }
            Bluetooth {
                barWindow: root
            }
            Backlight {}
            Network { barWindow: root }
            Battery { barWindow: root }
            SysInfo {
                barWindow: root
            }
            Row {
                spacing: 12
                Idle {}
                Notifications {}
                Power { ccRef: root.controlCenterRef }
            }
        }
    }
}
