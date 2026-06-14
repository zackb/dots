import QtQuick
import QtQuick.Controls
import qs.theme

// Secondary view shown over the result list when a contact is opened. Lists the
// contact's emails and phones; activating an email opens a Betterbird compose
// window, a phone copies to the clipboard. Enter emails the primary address, Esc
// returns to the list. Lives inside mainUi so it shares the launcher's Wayland
// surface and focus (no second popup).
FocusScope {
    id: detail

    readonly property var contact: launcherWindow.activeContact
    visible: contact !== null && contact !== undefined

    onVisibleChanged: {
        if (visible) {
            rowsList.currentIndex = 0;
            forceActiveFocus();
        }
    }

    // Flat, keyboard-navigable list: emails first, then phones.
    readonly property var rows: {
        var r = [];
        var em = (contact && contact.emails) || [];
        for (var i = 0; i < em.length; i++)
            r.push({ type: em[i].type || "Email", value: em[i].value, glyph: "mail", isEmail: true });
        var ph = (contact && contact.phones) || [];
        for (var j = 0; j < ph.length; j++)
            r.push({ type: ph[j].type || "Phone", value: ph[j].value, glyph: "call", isEmail: false });
        return r;
    }

    function activate(i) {
        var r = detail.rows[i];
        if (!r)
            return;
        if (r.isEmail)
            ctrl.emailContact(r.value, detail.contact.uid);
        else
            ctrl.copyValue(r.value);
    }

    function initialsOf(name) {
        const parts = ((name) || "").trim().split(/\s+/);
        if (parts.length === 0 || parts[0] === "")
            return "?";
        if (parts.length === 1)
            return parts[0].charAt(0).toUpperCase();
        return (parts[0].charAt(0) + parts[parts.length - 1].charAt(0)).toUpperCase();
    }

    function back() {
        launcherWindow.closeContact();
        searchField.forceActiveFocus();
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_H) {
            detail.back();
            event.accepted = true;
        } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
            rowsList.incrementCurrentIndex();
            event.accepted = true;
        } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
            rowsList.decrementCurrentIndex();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_L) {
            detail.activate(rowsList.currentIndex);
            event.accepted = true;
        }
    }

    // opaque backing so the list underneath doesn't show through
    Rectangle {
        anchors.fill: parent
        color: mainUi.color
    }

    // a value row (email or phone): label + value. Selectable by keyboard or
    // mouse; activating opens compose (email) or copies (phone).
    component DetailRow: Rectangle {
        id: rowRoot
        required property var modelData
        required property int index
        readonly property bool isSelected: ListView.isCurrentItem
        width: ListView.view ? ListView.view.width : 0
        height: 56
        radius: 14
        color: isSelected ? Theme.secondary_container
             : (rowMouse.containsMouse ? Qt.lighter(Theme.surface_container_low, 1.08) : "transparent")
        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        Text {
            id: rowGlyph
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: rowRoot.modelData.glyph
            font.family: Theme.ligatureFont
            font.pixelSize: 22
            color: rowRoot.isSelected ? Theme.on_secondary_container : Theme.primary
        }

        Column {
            anchors.left: rowGlyph.right
            anchors.leftMargin: 16
            anchors.right: rowAction.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: rowRoot.modelData.type
                color: rowRoot.isSelected ? Theme.on_secondary_container : Theme.on_surface_variant
                opacity: rowRoot.isSelected ? 0.8 : 1.0
                font.family: Theme.font
                font.pixelSize: 11
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: rowRoot.modelData.value
                color: rowRoot.isSelected ? Theme.on_secondary_container : Theme.on_surface
                font.family: Theme.font
                font.pixelSize: 16
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
        }

        Text {
            id: rowAction
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: rowRoot.modelData.isEmail ? "edit" : "content_copy"
            font.family: Theme.ligatureFont
            font.pixelSize: 18
            color: rowRoot.isSelected ? Theme.on_secondary_container : Theme.on_surface_variant
            opacity: (rowRoot.isSelected || rowMouse.containsMouse) ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                }
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: rowRoot.ListView.view.currentIndex = rowRoot.index
            onClicked: detail.activate(rowRoot.index)
        }
    }

    // header: back + avatar + name/org
    Item {
        id: headerRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 20
        anchors.leftMargin: 32
        anchors.rightMargin: 32
        height: 56

        Rectangle {
            id: backBtn
            width: 40
            height: 40
            radius: 20
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: backMouse.containsMouse ? Theme.surface_container_high : "transparent"
            Text {
                anchors.centerIn: parent
                text: "arrow_back"
                font.family: Theme.ligatureFont
                font.pixelSize: 24
                color: Theme.on_surface
            }
            MouseArea {
                id: backMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    launcherWindow.closeContact();
                    searchField.forceActiveFocus();
                }
            }
        }

        Rectangle {
            id: bigAvatar
            width: 56
            height: 56
            radius: 28
            anchors.left: backBtn.right
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.alpha(Theme.primary, 0.18)
            border.width: 1
            border.color: Qt.alpha(Theme.primary, 0.4)
            Text {
                anchors.centerIn: parent
                text: detail.initialsOf(detail.contact && detail.contact.name)
                color: Theme.primary
                font.family: Theme.font
                font.pixelSize: 22
                font.weight: Font.DemiBold
            }
        }

        Column {
            anchors.left: bigAvatar.right
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                width: parent.width
                text: (detail.contact && detail.contact.name) || ""
                color: Theme.on_surface
                font.family: Theme.font
                font.pixelSize: 24
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: !!(detail.contact && detail.contact.org)
                text: (detail.contact && detail.contact.org) || ""
                color: Theme.on_surface_variant
                font.family: Theme.font
                font.pixelSize: 14
                elide: Text.ElideRight
            }
        }
    }

    // scrollable, keyboard-navigable detail rows
    ListView {
        id: rowsList
        anchors.top: headerRow.bottom
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 32
        anchors.rightMargin: 32
        anchors.bottomMargin: 44
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 120
        highlightFollowsCurrentItem: true
        model: detail.rows
        delegate: DetailRow {}

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.top: parent.top
            anchors.topMargin: 12
            visible: detail.rows.length === 0
            text: "No contact methods"
            color: Theme.on_surface_variant
            font.family: Theme.font
            font.pixelSize: 15
        }
    }

    // hint
    Text {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 14
        text: "[Enter] Email  •  [Esc] Back"
        color: Theme.on_surface_variant
        opacity: 0.7
        font.family: Theme.font
        font.pixelSize: 12
        font.weight: Font.Medium
    }
}
