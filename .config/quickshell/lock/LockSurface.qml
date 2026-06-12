import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.theme

// One instance per screen (WlSessionLock instantiates the surface Component for
// each output). Visuals only -- all auth state lives in the LockState
// singleton, so every screen's password field drives the same single
// password/fingerprint attempt.
WlSessionLockSurface {
    id: surface

    // solid fallback so a crashed/late surface never reveals the desktop
    color: Theme.background

    // blurred wallpaper background
    Image {
        id: wallpaper
        anchors.fill: parent
        source: Theme.wallpaper ? "file://" + Theme.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
        visible: false              // drawn via the MultiEffect below
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        visible: wallpaper.status === Image.Ready
        blurEnabled: true
        blur: 1.0
        blurMax: Theme.lockBlurMax
        autoPaddingEnabled: false
    }

    // darkening scrim so the clock + field stay legible over any wallpaper
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: Theme.lockScrimOpacity
    }

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
            text: (clock.now.getHours() % 12 || 12) + ":"
                  + String(clock.now.getMinutes()).padStart(2, "0")
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

            // no caret
            cursorDelegate: Item {}

            background: Rectangle {
                color: Qt.tint(Theme.surface_container_highest, Qt.alpha(Theme.primary, 0.10))
                radius: height / 2
                border.width: pwField.activeFocus ? 2 : 1
                border.color: LockState.errorText !== "" ? Theme.critical
                              : (pwField.activeFocus ? Theme.primary : Qt.alpha(Theme.outline, 0.35))
                Behavior on border.color {
                    ColorAnimation { duration: 150 }
                }
            }

            onAccepted: {
                LockState.submitPassword(text)
                text = ""
            }
            // clear the error as soon as the user starts typing again
            onTextChanged: if (text !== "" && LockState.errorText !== "") LockState.errorText = ""
        }

        // status line: password errors only
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: text !== ""
            text: LockState.errorText
            color: Theme.critical
            font.family: Theme.font
            font.pixelSize: Theme.font_size_sm
        }
    }

    // grab keyboard focus for the password field when this surface appears
    onVisibleChanged: if (visible) pwField.forceActiveFocus()
    Component.onCompleted: pwField.forceActiveFocus()
}
