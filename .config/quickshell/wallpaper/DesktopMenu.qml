// Desktop right-click menu: installed apps grouped by freedesktop category
import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.lock
import qs.compositor

PanelWindow {
    id: root

    property bool isOpen: false
    property real anchorX: 0           // cursor x in screen space
    property real anchorY: 0           // cursor y in screen space
    property var  items: []
    property var  activeItem: null     // submenu whose flyout is shown
    property real activeRowY: 0         // screen y of the active row's top
    property int  hoverDepth: 0         // # of rows currently hovered (panel + flyout)

    readonly property int menuWidth:   240
    readonly property int flyoutWidth: 240
    readonly property real screenW: screen ? screen.width  : 1920
    readonly property real screenH: screen ? screen.height : 1080

    visible: false
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode:               ExclusionMode.Ignore
    color: "transparent"

    function openAt(x, y) {
        items      = buildModel()
        activeItem = null
        hoverDepth = 0
        anchorX    = x
        anchorY    = y
        isOpen     = true
    }

    onIsOpenChanged: if (!isOpen) activeItem = null

    // Launch like dock/DockState.qml: terminal-wrap then spawn via the compositor.
    function launch(e) {
        if (!e)
            return
        var parts = e.runInTerminal ? ["ghostty", "-e"] : []
        parts = parts.concat(e.command)
        Compositor.spawn(parts, e.workingDirectory)
    }

    // Icon source resolution, mirrors launcher/ResultDelegate.qml.
    function iconFor(e) {
        if (!e || !e.icon || e.icon === "")
            return "image://icon/application-x-executable"
        if (e.icon.startsWith("/"))
            return "file://" + e.icon
        return "image://icon/" + e.icon
    }

    function buildModel() {
        // Fixed category order; `keys` are freedesktop main categories.
        const CATS = [
            { label: "Accessories", glyph: "build",            keys: ["Utility"] },
            { label: "Development", glyph: "code",             keys: ["Development"] },
            { label: "Education",   glyph: "school",           keys: ["Education"] },
            { label: "Games",       glyph: "sports_esports",   keys: ["Game"] },
            { label: "Graphics",    glyph: "palette",          keys: ["Graphics"] },
            { label: "Internet",    glyph: "public",           keys: ["Network"] },
            { label: "Multimedia",  glyph: "movie",            keys: ["AudioVideo", "Audio", "Video"] },
            { label: "Office",      glyph: "work",             keys: ["Office"] },
            { label: "Science",     glyph: "science",          keys: ["Science"] },
            { label: "Settings",    glyph: "settings",         keys: ["Settings"] },
            { label: "System",      glyph: "monitor_heart",    keys: ["System"] },
        ]

        var buckets = ({})
        for (var i = 0; i < CATS.length; i++)
            buckets[CATS[i].label] = []
        var other = []

        var apps = DesktopEntries.applications.values
        for (var a = 0; a < apps.length; a++) {
            var app  = apps[a]
            var cats = app.categories || []
            var matched = false
            for (var c = 0; c < CATS.length; c++) {
                var keys = CATS[c].keys
                var hit = false
                for (var k = 0; k < keys.length; k++) {
                    if (cats.indexOf(keys[k]) >= 0) { hit = true; break }
                }
                if (hit) {                              // listed under every match
                    buckets[CATS[c].label].push(app)
                    matched = true
                }
            }
            if (!matched)
                other.push(app)
        }

        function byName(x, y) {
            return (x.name || "").toLowerCase().localeCompare((y.name || "").toLowerCase())
        }
        // inFlyout: true marks rows that live in a flyout
        function appChild(e) {
            return { kind: "action", inFlyout: true, label: e.name, iconSource: root.iconFor(e),
                     activate: function() { root.launch(e) } }
        }

        var model = []
        for (var ci = 0; ci < CATS.length; ci++) {
            var bucket = buckets[CATS[ci].label]
            if (bucket.length === 0)
                continue
            bucket.sort(byName)
            model.push({ kind: "submenu", label: CATS[ci].label,
                         glyph: CATS[ci].glyph, children: bucket.map(appChild) })
        }
        if (other.length > 0) {
            other.sort(byName)
            model.push({ kind: "submenu", label: "Other", glyph: "apps",
                         children: other.map(appChild) })
        }

        // shell actions
        model.push({ kind: "separator" })
        model.push({ kind: "action", label: "Open Launcher", glyph: "search",
            activate: function() { Quickshell.execDetached(["qs", "ipc", "call", "launcher", "toggle"]) } })
        model.push({ kind: "action", label: "Change Wallpaper…", glyph: "wallpaper",
            activate: function() { Quickshell.execDetached(["/home/zackb/bin/wallpaper.sh"]) } })
        model.push({ kind: "action", label: "Lock", glyph: "lock",
            activate: function() { LockState.engageLock() } })
        model.push({ kind: "submenu", label: "Power", glyph: "power_settings_new", children: [
            { kind: "action", inFlyout: true, label: "Sleep",     glyph: "bedtime",            activate: function() { Quickshell.execDetached(["systemctl", "suspend"]) } },
            { kind: "action", inFlyout: true, label: "Hibernate", glyph: "mode_standby",       activate: function() { Quickshell.execDetached(["systemctl", "hibernate"]) } },
            { kind: "action", inFlyout: true, label: "Logout",    glyph: "logout",             activate: function() { Compositor.exit() } },
            { kind: "action", inFlyout: true, label: "Restart",   glyph: "restart_alt",        activate: function() { Quickshell.execDetached(["systemctl", "reboot"]) } },
            { kind: "action", inFlyout: true, label: "Shutdown",  glyph: "power_settings_new", activate: function() { Quickshell.execDetached(["systemctl", "poweroff"]) } },
        ] })
        model.push({ kind: "separator" })
        model.push({ kind: "action", label: "Toggle Bar", glyph: "visibility",
            activate: function() { Quickshell.execDetached(["qs", "ipc", "call", "shell", "toggle"]) } })
        model.push({ kind: "action", label: "Reload Shell", glyph: "refresh",
            activate: function() { Quickshell.reload(false) } })

        return model
    }

    // Grace window for crossing the gap between a category row and its flyout.
    Timer {
        id: flyoutCloseTimer
        interval: 200
        onTriggered: root.activeItem = null
    }

    // Backdrop: outside click dismisses.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: root.isOpen = false
        z: -1
    }

    // main panel
    Rectangle {
        id: panel
        width:  root.menuWidth
        height: mainCol.implicitHeight + 12
        x: Math.min(Math.max(root.anchorX, 10), root.screenW - width  - 10)
        y: Math.min(Math.max(root.anchorY, 10), root.screenH - height - 10)
        color:  Theme.popupBg
        radius: Theme.radius
        border.color: Theme.popupBorder
        border.width: 1

        transform: Translate { id: slide; y: root.isOpen ? 0 : 8 }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            color: "transparent"
            border.color: Qt.rgba(0, 0, 0, 0.4)
            border.width: 1
            radius: Theme.radius + 1
            z: -1
        }

        MouseArea { anchors.fill: parent }   // swallow clicks on the panel

        Column {
            id: mainCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
            spacing: 0

            Repeater {
                model: root.items
                delegate: menuRowComp
            }
        }

        states: [
            State {
                name: "open"; when: root.isOpen
                PropertyChanges { target: panel; opacity: 1.0 }
            },
            State {
                name: "closed"; when: !root.isOpen
                PropertyChanges { target: panel; opacity: 0.0 }
            }
        ]
        transitions: [
            Transition {
                from: "closed"; to: "open"
                SequentialAnimation {
                    ScriptAction { script: root.visible = true }
                    ParallelAnimation {
                        NumberAnimation { target: panel; property: "opacity"; duration: 160; easing.type: Easing.OutQuad }
                        NumberAnimation { target: slide; property: "y";       duration: 160; easing.type: Easing.OutQuad }
                    }
                }
            },
            Transition {
                from: "open"; to: "closed"
                SequentialAnimation {
                    NumberAnimation { target: panel; property: "opacity"; duration: 130; easing.type: Easing.OutQuad }
                    ScriptAction { script: root.visible = false }
                }
            }
        ]
    }

    // flyout (submenu)
    Rectangle {
        id: flyout
        visible: root.isOpen && root.activeItem !== null && root.activeItem.kind === "submenu"
        width:  root.flyoutWidth
        height: flyCol.implicitHeight + 12
        // abut the panel (no dead gap); flip to the left side near screen edge
        readonly property bool flipped: panel.x + panel.width + width > root.screenW - 10
        x: flipped ? panel.x - width + 1 : panel.x + panel.width - 1
        y: Math.min(Math.max(root.activeRowY, 10), root.screenH - height - 10)
        color:  Theme.popupBg
        radius: Theme.radius
        border.color: Theme.popupBorder
        border.width: 1

        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            color: "transparent"
            border.color: Qt.rgba(0, 0, 0, 0.4)
            border.width: 1
            radius: Theme.radius + 1
            z: -1
        }

        // Swallow clicks on flyout padding so they don't fall through to the
        // backdrop. Hover/keep-open is handled per-row (see menuRowComp).
        MouseArea { anchors.fill: parent }

        Column {
            id: flyCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
            spacing: 0

            Repeater {
                model: root.activeItem ? root.activeItem.children : []
                delegate: menuRowComp
            }
        }
    }

    // one row, used by both the main panel and the flyout
    Component {
        id: menuRowComp

        Item {
            id: rowItem
            required property var modelData
            width: parent ? parent.width : 0
            height: modelData.kind === "separator" ? 7 : 28

            // separator
            Rectangle {
                visible: rowItem.modelData.kind === "separator"
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                height: 1
                color: Theme.surface_container_highest
                opacity: 0.5
            }

            // clickable row
            Rectangle {
                id: cell
                visible: rowItem.modelData.kind !== "separator"
                // the open submenu's row stays highlighted while its flyout shows
                readonly property bool isActive: rowItem.modelData === root.activeItem
                anchors.fill: parent
                radius: Theme.radius_sm
                color: isActive
                    ? Theme.secondary_container
                    : (rowMouse.containsMouse ? Qt.alpha(Theme.primary, 0.18) : "transparent")
                Behavior on color { ColorAnimation { duration: 110 } }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    // app icon (image) or category/action glyph
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: rowItem.modelData.iconSource !== undefined
                        width:  visible ? 16 : 0
                        height: 16
                        sourceSize.width:  16
                        sourceSize.height: 16
                        source: rowItem.modelData.iconSource !== undefined ? rowItem.modelData.iconSource : ""
                        onStatusChanged: if (status === Image.Error) source = "image://icon/application-x-executable"
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: rowItem.modelData.iconSource === undefined && rowItem.modelData.glyph !== undefined
                        width: visible ? 16 : 0
                        horizontalAlignment: Text.AlignHCenter
                        text: rowItem.modelData.glyph !== undefined ? rowItem.modelData.glyph : ""
                        color: cell.isActive ? Theme.on_secondary_container : Theme.primary
                        font.family: Theme.ligatureFont
                        font.pixelSize: 16
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x - chevron.width - 8
                        text: rowItem.modelData.label || ""
                        color: cell.isActive ? Theme.on_secondary_container : Theme.on_surface
                        font.pixelSize: Theme.fontSize - 3
                        font.family: Theme.font
                        elide: Text.ElideRight
                    }
                }

                Text {
                    id: chevron
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    visible: rowItem.modelData.kind === "submenu"
                    width: visible ? 14 : 0
                    horizontalAlignment: Text.AlignRight
                    text: ""   // nerd font chevron-right
                    color: cell.isActive ? Theme.on_secondary_container : Theme.primary
                    font.family: Theme.nerdFont
                    font.pixelSize: 11
                }

                // One MouseArea per row is the single source of hover truth.
                // hoverDepth counts how many rows are hovered; because MouseArea
                // fires the new row's `entered` BEFORE the old row's `exited`.
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        root.hoverDepth++
                        flyoutCloseTimer.stop()
                        if (rowItem.modelData.kind === "submenu") {
                            root.activeRowY = rowItem.mapToItem(null, 0, 0).y
                            root.activeItem = rowItem.modelData
                        } else if (rowItem.modelData.inFlyout !== true) {
                            root.activeItem = null
                        }
                    }
                    onExited: {
                        root.hoverDepth--
                        if (root.hoverDepth <= 0) {
                            root.hoverDepth = 0
                            flyoutCloseTimer.restart()
                        }
                    }
                    onClicked: {
                        if (rowItem.modelData.kind === "action") {
                            rowItem.modelData.activate()
                            root.isOpen = false
                        }
                    }
                }
            }
        }
    }
}
