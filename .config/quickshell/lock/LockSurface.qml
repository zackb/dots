import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import "../"

// One instance per screen (WlSessionLock instantiates the surface Component for
// each output). Visuals only -- all auth state lives in the LockState
// singleton, so every screen's password field drives the same single
// password/fingerprint attempt.
WlSessionLockSurface {
    id: surface

    // solid fallback so a crashed/late surface never reveals the desktop
    color: Theme.background

    Timer {
        id: clock
        property var now: new Date()
        interval: 1000
        running: true
        repeat: true
        onTriggered: now = new Date()
    }

    Column {
        anchors.centerIn: parent
        spacing: 16
        width: 340

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clock.now, "HH:mm")
            color: Theme.on_surface
            font.pixelSize: 88
            font.family: Theme.font
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(clock.now, "dddd, MMMM d")
            color: Theme.on_surface_variant
            font.pixelSize: 20
            font.family: Theme.font
            bottomPadding: 12
        }

        TextField {
            id: pwField
            width: parent.width
            enabled: !LockState.busy
            echoMode: TextInput.Password
            placeholderText: "Password"
            color: Theme.on_surface
            placeholderTextColor: Theme.on_surface_variant
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            horizontalAlignment: TextInput.AlignHCenter
            leftPadding: 16
            rightPadding: 16
            topPadding: 12
            bottomPadding: 12

            background: Rectangle {
                color: Theme.surface_container
                radius: Theme.radius
                border.width: 1
                border.color: LockState.errorText !== "" ? Theme.critical
                              : (pwField.activeFocus ? Theme.primary : Theme.outline)
            }

            onAccepted: {
                LockState.submitPassword(text)
                text = ""
            }
            // clear the error as soon as the user starts typing again
            onTextChanged: if (text !== "" && LockState.errorText !== "") LockState.errorText = ""
        }

        // status line: error (red) takes priority over the fingerprint hint
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: text !== ""
            text: LockState.errorText !== "" ? LockState.errorText : LockState.fpHint
            color: LockState.errorText !== "" ? Theme.critical : Theme.on_surface_variant
            font.family: Theme.font
            font.pixelSize: Theme.font_size_sm
        }
    }

    // grab keyboard focus for the password field when this surface appears
    onVisibleChanged: if (visible) pwField.forceActiveFocus()
    Component.onCompleted: pwField.forceActiveFocus()
}
