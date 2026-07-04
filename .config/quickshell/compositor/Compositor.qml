pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

// One compositor-agnostic interface for the bits of the shell that touch the
// window manager: the workspace list, the active window, workspace switching, and
// app spawning. Picks its backend once from the environment — fenriz exports
// FENRIZ_SOCKET, Hyprland doesn't — and normalizes both to the same shape so no
// widget imports Quickshell.Hyprland directly.
Singleton {
    id: root

    readonly property string kind: Quickshell.env("FENRIZ_SOCKET") ? "fenriz" : "hyprland"

    // [{ id, focused, occupied, urgent }], ascending by id.
    readonly property var workspaces: kind === "fenriz" ? _fenrizWs : _hyprWs
    // { appId, title } of the focused window, or null.
    readonly property var activeWindow: kind === "fenriz" ? _fenrizWin : _hyprWin

    function focusWorkspace(id) {
        if (kind === "fenriz")
            _sock.write(JSON.stringify({ cmd: "workspace", n: id }) + "\n")
        else
            Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + id + "\" })")
    }

    // argv is a plain command array. Under Hyprland we hand it to the compositor so
    // the child reparents to it; under fenriz (no exec IPC) we just spawn it.
    function spawn(argv, workingDirectory) {
        if (kind === "fenriz")
            Quickshell.execDetached({ command: argv, workingDirectory: workingDirectory })
        else
            Quickshell.execDetached({
                command: ["hyprctl", "dispatch", 'hl.dsp.exec_cmd("' + argv.join(" ") + '")'],
                workingDirectory: workingDirectory
            })
    }

    // ---- Hyprland backend (guarded so its objects are never touched under fenriz) ----
    readonly property var _hyprWs: (kind === "hyprland" && Hyprland.workspaces)
        ? Hyprland.workspaces.values
            .filter(ws => ws.id > 0)
            .map(ws => ({
                id: ws.id,
                focused: ws.id === Hyprland.focusedMonitor?.activeWorkspace?.id,
                occupied: true,
                urgent: ws.toplevels.values.some(c => c.urgent)
            }))
        : []
    readonly property var _hyprWin: {
        if (kind !== "hyprland")
            return null
        const t = Hyprland.activeToplevel
        return t ? ({ appId: t.lastIpcObject?.class ?? "", title: t.title ?? "" }) : null
    }

    // HACK preserved from the old ActiveWindow.qml: the activeToplevel IPC object is
    // stale for freshly-mapped apps until a refresh.
    Connections {
        target: Hyprland
        enabled: root.kind === "hyprland"
        function onActiveToplevelChanged() { Hyprland.refreshToplevels() }
    }

    // ---- fenriz backend (FENRIZ_SOCKET NDJSON feed; see fenriz/docs/IPC.md) ----
    property var _fenrizWs: []
    property var _fenrizWin: null
    Socket {
        id: _sock
        path: Quickshell.env("FENRIZ_SOCKET")
        connected: root.kind === "fenriz"
        parser: SplitParser {
            onRead: line => {
                let s
                try { s = JSON.parse(line) } catch (e) { return }
                const active = s.workspaces.active
                root._fenrizWs = (s.workspaces.occupied || []).map(id => ({
                    id: id, focused: id === active, occupied: true, urgent: false
                }))
                root._fenrizWin = s.activeWindow || null
            }
        }
    }
}
