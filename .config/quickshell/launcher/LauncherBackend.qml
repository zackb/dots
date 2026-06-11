import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: backend

    // UI Orchestration Signals
    signal openMenuRequested
    signal closeMenuRequested

    property string searchText: ""

    property string myTerminal: "ghostty"

    // Per-desktop-entry usage for frecency ranking.
    // { "<DesktopEntry.id>": { count: N, last: <epochMs> } }
    property var usage: ({})

    // Persisted to disk; the launcher is the only writer
    FileView {
        id: usageFile
        path: Quickshell.shellPath("launcher_usage.json")
        onLoaded: backend._loadUsage()
    }

    function _loadUsage() {
        try { backend.usage = JSON.parse(usageFile.text()) }
        catch (e) { backend.usage = {} }
    }

    function recordUse(id) {
        if (!id)
            return;
        const u = backend.usage[id] || { count: 0, last: 0 };
        u.count += 1;
        u.last = Date.now();
        // reassign so bindings (the launcher's sort) re-evaluate
        backend.usage = Object.assign({}, backend.usage, { [id]: u });
        usageFile.setText(JSON.stringify(backend.usage));
    }

    function _recencyWeight(ageMs) {
        const day = 86400000;
        if (ageMs < day)      return 1.0;
        if (ageMs < 3 * day)  return 0.7;
        if (ageMs < 7 * day)  return 0.5;
        if (ageMs < 30 * day) return 0.25;
        return 0.1;
    }

    function frecency(id) {
        const u = backend.usage[id];
        if (!u)
            return 0;
        return u.count * backend._recencyWeight(Date.now() - u.last);
    }

    function launchApp(desktopEntry) {
        backend.recordUse(desktopEntry.id);

        var parts = [];

        if (desktopEntry.runInTerminal) {
            parts.push(myTerminal);
            parts.push("-e"); // "--" for kitty
        }

        parts = parts.concat(desktopEntry.command);

        Quickshell.execDetached({
            command: ["hyprctl", "dispatch", 'hl.dsp.exec_cmd("' + parts.join(" ") + '")'],
            workingDirectory: desktopEntry.workingDirectory
        });

        backend.closeMenuRequested();
    }

    IpcHandler {
        target: "launcher"
        function toggle() {
            backend.openMenuRequested();
        }
    }
}
