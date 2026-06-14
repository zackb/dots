import QtQuick
import Quickshell.Widgets
import qs.theme

// One launcher result row. modelData is a wrapper: { kind: "app", app } or
// { kind: "contact", contact }. App rows keep the original LauncherDelegate look;
// contact rows show an initials avatar and open the contact detail view.
Item {
    id: delegateRoot
    width: ListView.view ? ListView.view.width : 0
    height: 72

    required property var modelData
    // declaring modelData required puts the delegate in required-properties mode,
    // so the view's index must be declared explicitly too.
    required property int index

    readonly property bool isApp: modelData.kind === "app"
    readonly property var app: modelData.app
    readonly property var contact: modelData.contact

    property bool isSelected: ListView.isCurrentItem
    property bool isHovered: itemMouseArea.containsMouse

    readonly property string titleText: isApp ? (app.name || "") : (contact.name || "")
    readonly property string descriptionText: isApp
        ? (app.genericName ? app.genericName : (app.comment ? app.comment : ""))
        : delegateRoot.contactSubtitle()

    function contactSubtitle() {
        if (contact.emails && contact.emails.length > 0)
            return contact.emails[0].value;
        if (contact.org)
            return contact.org;
        if (contact.phones && contact.phones.length > 0)
            return contact.phones[0].value;
        return "";
    }

    function initials() {
        const parts = (contact.name || "").trim().split(/\s+/);
        if (parts.length === 0 || parts[0] === "")
            return "?";
        if (parts.length === 1)
            return parts[0].charAt(0).toUpperCase();
        return (parts[0].charAt(0) + parts[parts.length - 1].charAt(0)).toUpperCase();
    }

    // Keyboard/click activation. Name kept as launch() for the ListView keynav.
    function launch() {
        if (isApp)
            ctrl.launchApp(app);
        else
            launcherWindow.openContact(contact);
    }

    Rectangle {
        id: itemBox
        anchors.centerIn: parent
        width: parent.width - 32
        height: parent.height - 4
        radius: 16

        scale: itemMouseArea.pressed ? 0.98 : (delegateRoot.isSelected || delegateRoot.isHovered ? 1.015 : 1.0)
        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutBack
            }
        }

        color: delegateRoot.isSelected ? Theme.secondary_container : (delegateRoot.isHovered ? Qt.lighter(Theme.surface_container_low, 1.08) : "transparent")
        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        Rectangle {
            id: activeIndicator
            width: 4
            height: delegateRoot.isSelected ? parent.height * 0.5 : 0
            opacity: delegateRoot.isSelected ? 1.0 : 0.0
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            radius: 2
            color: Theme.primary
            Behavior on height {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutQuart
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }
        }

        // App icon
        IconImage {
            id: appIcon
            visible: delegateRoot.isApp
            width: 42
            height: 42
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter

            source: {
                if (!delegateRoot.isApp)
                    return "";
                if (!delegateRoot.app.icon || delegateRoot.app.icon === "")
                    return "image://icon/application-x-executable";
                if (delegateRoot.app.icon.startsWith("/"))
                    return "file://" + delegateRoot.app.icon;
                return "image://icon/" + delegateRoot.app.icon;
            }

            onStatusChanged: {
                if (status === Image.Error)
                    source = "image://icon/application-x-executable";
            }
        }

        // Contact avatar (initials)
        Rectangle {
            id: avatar
            visible: !delegateRoot.isApp
            width: 42
            height: 42
            radius: 21
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.alpha(Theme.primary, 0.18)
            border.width: 1
            border.color: Qt.alpha(Theme.primary, 0.4)

            Text {
                anchors.centerIn: parent
                text: delegateRoot.isApp ? "" : delegateRoot.initials()
                color: Theme.primary
                font {
                    family: Theme.font
                    pixelSize: 16
                    weight: Font.DemiBold
                }
            }
        }

        Column {
            anchors.left: appIcon.right
            anchors.right: launchPill.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 2

            Text {
                width: parent.width
                text: delegateRoot.titleText
                color: delegateRoot.isSelected ? Theme.on_secondary_container : Theme.on_surface
                elide: Text.ElideRight
                font {
                    family: Theme.font
                    pixelSize: 16
                    weight: Font.DemiBold
                }
            }

            Text {
                width: parent.width
                text: delegateRoot.descriptionText
                visible: delegateRoot.descriptionText !== ""
                color: delegateRoot.isSelected ? Theme.on_secondary_container : Theme.on_surface_variant
                opacity: delegateRoot.isSelected ? 0.8 : 1.0
                elide: Text.ElideRight
                font {
                    family: Theme.font
                    pixelSize: 13
                }
            }
        }

        Rectangle {
            id: launchPill
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 86
            height: 32
            radius: 16
            color: Theme.primary
            opacity: delegateRoot.isSelected ? 1.0 : 0.0
            scale: delegateRoot.isSelected ? 1.0 : 0.8

            Behavior on opacity {
                NumberAnimation {
                    duration: 100
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 100
                    easing.type: Easing.OutBack
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    topPadding: 2
                    verticalAlignment: Text.AlignVCenter
                    text: delegateRoot.isApp ? "Launch" : "Open"
                    color: Theme.on_primary
                    font {
                        family: "Google Sans Medium"
                        pixelSize: 13
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    topPadding: 2
                    verticalAlignment: Text.AlignVCenter
                    text: delegateRoot.isApp ? "keyboard_return" : "person"
                    color: Theme.on_primary
                    font {
                        family: Theme.ligatureFont
                        pixelSize: 16
                    }
                }
            }
        }

        MouseArea {
            id: itemMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: delegateRoot.ListView.view.currentIndex = index
            onClicked: delegateRoot.launch()
        }
    }
}
