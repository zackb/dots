pragma Singleton

import Quickshell
import QtQuick
import qs.store

// Persistent dock configuration + app-launching.
// enabled/position survive reloads (dock.json); pinnedApps is source config
// you edit here and hot-reload.
Singleton {
    id: root

    // user-facing settings

    // Toggled from the Control Center. Persisted.
    property bool enabled: false

    // "bottom" | "left" | "right". Persisted.
    property string position: "bottom"
    readonly property var positions: ["bottom", "left", "right"]

    // Apps to show, DesktopEntry id (the .desktop basename, see DesktopEntries.heuristicLookup
    property var pinnedApps: [
        "zen-browser",
        "com.mitchellh.ghostty",
        "org.gnome.Nautilus",
        "code",
        "spotify",
        "discord",
    ]

    // launching

    function launch(id) {
        const e = DesktopEntries.heuristicLookup(id)
        if (!e)
            return

        var parts = e.runInTerminal ? ["ghostty", "-e"] : []
        parts = parts.concat(e.command)

        Quickshell.execDetached({
            command: ["hyprctl", "dispatch", 'hl.dsp.exec_cmd("' + parts.join(" ") + '")'],
            workingDirectory: e.workingDirectory
        })
    }

    // persistence (store/Store.qml, like lock/LockState.qml)

    readonly property string _stateFile: "dock.json"

    Component.onCompleted: {
        const s = Store.readJson(root._stateFile, { enabled: false, position: "bottom" })
        root.enabled  = s.enabled === true
        if (root.positions.indexOf(s.position) !== -1)
            root.position = s.position
        root._ready = true
    }

    // guard so the initial restore doesn't immediately rewrite the file
    property bool _ready: false

    function _persist() {
        if (!root._ready)
            return
        Store.writeJson(root._stateFile, {
            enabled: root.enabled,
            position: root.position
        })
    }

    onEnabledChanged:  _persist()
    onPositionChanged: _persist()
}
