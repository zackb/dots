import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import QtQuick
import QtQuick.Controls
import "../"

// PolicyKit authentication agent.
Scope {
    id: root

    PolkitAgent {
        id: agent
        // default path "/org/quickshell/Polkit" is fine
        onIsRegisteredChanged: console.log("polkit agent registered:", isRegistered)
    }

    // the live AuthFlow, or null when no request is in flight. nullable
    readonly property var flow: agent.flow

    // Modal dialog, mapped only while a request is active so the Wayland surface
    PanelWindow {
        id: dialog
        visible: agent.isActive
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "polkit_dialog"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive  // capture the password
        exclusiveZone: -1

        anchors { top: true; bottom: true; left: true; right: true }

        // darkening backdrop
        Rectangle {
            anchors.fill: parent
            color: Theme.scrim
            opacity: 0.5
        }

        // card
        Rectangle {
            anchors.centerIn: parent
            width: 380
            implicitHeight: card.implicitHeight + 48
            radius: Theme.radius
            color: Theme.surface_container
            border.width: 1
            border.color: Theme.popupBorder

            Column {
                id: card
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    margins: 24
                }
                spacing: 14

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰌾"               // nf-md-shield_key
                    font.family: Theme.nerdFont
                    font.pixelSize: 44
                    color: Theme.primary
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Authentication Required"
                    color: Theme.on_surface
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 2
                    font.weight: Font.Medium
                }

                // the action's human-readable reason
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: root.flow ? root.flow.message : ""
                    color: Theme.on_surface_variant
                    font.family: Theme.font
                    font.pixelSize: Theme.font_size_sm + 1
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                // which identity we're authenticating as (only when ambiguous)
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.flow && root.flow.identities && root.flow.identities.length > 1
                    text: root.flow && root.flow.selectedIdentity
                          ? root.flow.selectedIdentity.toString() : ""
                    color: Theme.on_surface_variant
                    font.family: Theme.font
                    font.pixelSize: Theme.font_size_sm
                }

                TextField {
                    id: pwField
                    width: parent.width
                    enabled: root.flow ? root.flow.isResponseRequired : false
                    echoMode: (root.flow && root.flow.responseVisible)
                              ? TextInput.Normal : TextInput.Password
                    placeholderText: (root.flow && root.flow.inputPrompt)
                                     ? root.flow.inputPrompt : "Password"
                    color: Theme.on_surface
                    placeholderTextColor: Theme.on_surface_variant
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    horizontalAlignment: TextInput.AlignHCenter
                    leftPadding: 16
                    rightPadding: 16
                    topPadding: 12
                    bottomPadding: 12

                    cursorDelegate: Item {}     // no caret

                    background: Rectangle {
                        color: Qt.tint(Theme.surface_container_highest, Qt.alpha(Theme.primary, 0.10))
                        radius: height / 2
                        border.width: pwField.activeFocus ? 2 : 1
                        border.color: (root.flow && root.flow.supplementaryIsError)
                                      ? Theme.critical
                                      : (pwField.activeFocus ? Theme.primary : Qt.alpha(Theme.outline, 0.35))
                        Behavior on border.color {
                            ColorAnimation { duration: 150 }
                        }
                    }

                    onAccepted: if (root.flow) root.flow.submit(text)
                }

                // PAM feedback: "Incorrect password" (error) or hints
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: root.flow ? root.flow.supplementaryMessage : ""
                    color: (root.flow && root.flow.supplementaryIsError)
                           ? Theme.critical : Theme.on_surface_variant
                    font.family: Theme.font
                    font.pixelSize: Theme.font_size_sm
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                // buttons
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    component DialogButton: Rectangle {
                        property alias label: btnText.text
                        property color accent: Theme.primary
                        signal clicked
                        width: 140
                        height: 40
                        radius: height / 2
                        color: hover.hovered ? Qt.alpha(accent, 0.18) : Qt.alpha(accent, 0.10)
                        border.width: 1
                        border.color: Qt.alpha(accent, 0.5)

                        Text {
                            id: btnText
                            anchors.centerIn: parent
                            color: parent.accent
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            font.weight: Font.Medium
                        }

                        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: parent.clicked() }
                    }

                    DialogButton {
                        label: "Cancel"
                        accent: Theme.on_surface_variant
                        onClicked: if (root.flow) root.flow.cancelAuthenticationRequest()
                    }

                    DialogButton {
                        label: "Authenticate"
                        accent: Theme.primary
                        onClicked: if (root.flow) root.flow.submit(pwField.text)
                    }
                }
            }

            // esc cancels from anywhere in the dialog
            Keys.onEscapePressed: if (root.flow) root.flow.cancelAuthenticationRequest()
        }

        // on a fresh request: clear + focus the field. 
        // on a failed attempt: clear it so the user can retype.
        Connections {
            target: agent
            function onIsActiveChanged() {
                if (agent.isActive) {
                    pwField.text = ""
                    Qt.callLater(() => pwField.forceActiveFocus())
                }
            }
        }
        Connections {
            target: root.flow
            ignoreUnknownSignals: true
            function onFailedChanged() {
                if (root.flow && root.flow.failed)
                    pwField.text = ""
            }
        }
    }
}
